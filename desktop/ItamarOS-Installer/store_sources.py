"""Safe, opt-in community app catalogs for the ItamarOS Windows storefront.

ItamarOS Official is immutable and always included. Community sources must
use HTTPS and cannot claim to be official; downloading an IPA is never the
same as installing it or verifying the publisher's signing certificate.
"""
from __future__ import annotations

import ipaddress
import json
import os
import plistlib
import re
import socket
import tempfile
import urllib.error
import urllib.parse
import urllib.request
import uuid
import zipfile
from pathlib import Path

from official_catalog import OfficialCatalog, MAX_IPA

BASE_DIR = Path(os.environ.get("LOCALAPPDATA", Path.home())) / "ItamarOS Installer"
SOURCES_PATH = BASE_DIR / "custom-sources.json"
SAFE_ID = re.compile(r"^[A-Za-z0-9._-]{2,120}$")


class InvalidSource(ValueError):
    pass


def public_https(url: str) -> str:
    if len(url) > 1200:
        raise InvalidSource("Source URL is too long.")
    parts = urllib.parse.urlsplit(url.strip())
    host = (parts.hostname or "").lower()
    if (parts.scheme.lower() != "https" or not host or parts.username or
            parts.password or parts.fragment or parts.port not in (None, 443)):
        raise InvalidSource("Use a public HTTPS URL with no embedded credentials or port.")
    if (host in {"localhost", "localhost.localdomain"} or
            host.endswith((".local", ".lan", ".internal", ".test"))):
        raise InvalidSource("Private-network sources are not allowed.")
    try:
        ipaddress.ip_address(host)
    except ValueError:
        pass
    else:
        raise InvalidSource("Use a public HTTPS hostname, not an IP address.")
    return urllib.parse.urlunsplit(parts)


def resolve_public_host(url: str) -> None:
    """Reject internal DNS answers before each source fetch/redirect."""
    host = urllib.parse.urlsplit(public_https(url)).hostname
    try:
        records = socket.getaddrinfo(host, 443, type=socket.SOCK_STREAM)
    except OSError as exc:
        raise InvalidSource("Source hostname cannot be resolved.") from exc
    addresses = [ipaddress.ip_address(row[4][0]) for row in records]
    if not addresses or any(not ip.is_global for ip in addresses):
        raise InvalidSource("The source hostname resolves to a private network.")


class HTTPSOnlyRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        verified = public_https(newurl)
        resolve_public_host(verified)
        return super().redirect_request(req, fp, code, msg, headers, verified)


def retrieve(url: str, max_bytes: int) -> bytes:
    checked = public_https(url)
    resolve_public_host(checked)
    request = urllib.request.Request(checked, headers={
        "User-Agent": "ItamarOS-Store/1.0", "Accept": "application/json, application/octet-stream",
    })
    opener = urllib.request.build_opener(HTTPSOnlyRedirect)
    with opener.open(request, timeout=18) as response:
        length = response.headers.get("Content-Length", "")
        if length.isdigit() and int(length) > max_bytes:
            raise InvalidSource("The source file exceeds the permitted size.")
        data = response.read(max_bytes + 1)
        if len(data) > max_bytes:
            raise InvalidSource("The source file exceeds the permitted size.")
        return data


class CommunitySources:
    def __init__(self, official: OfficialCatalog | None = None,
                 file: Path = SOURCES_PATH):
        self.official = official or OfficialCatalog()
        self.file = file
        self.sources: list[dict] = []
        self.community_apps: list[dict] = []
        self.load()

    def load(self):
        if not self.file.is_file():
            return
        try:
            rows = json.loads(self.file.read_text(encoding="utf-8"))
            if not isinstance(rows, list):
                return
            accepted = []
            for row in rows[:19]:
                if not isinstance(row, dict):
                    continue
                try:
                    url = public_https(str(row.get("url", "")))
                except (ValueError, TypeError):
                    continue
                accepted.append({"id": str(row.get("id", uuid.uuid4().hex))[:64],
                                 "url": url, "name": str(row.get("name", "Community"))[:100],
                                 "enabled": bool(row.get("enabled", True)),
                                 "official": False})
            self.sources = accepted
        except (OSError, ValueError):
            self.sources = []

    def save(self):
        self.file.parent.mkdir(parents=True, exist_ok=True)
        self.file.write_text(json.dumps(self.sources, indent=2), encoding="utf-8")

    def add(self, url: str) -> dict:
        verified = public_https(url)
        if any(s["url"] == verified for s in self.sources):
            raise InvalidSource("This community source has already been added.")
        if len(self.sources) >= 19:
            raise InvalidSource("The source limit is 19 community sources.")
        source = {"id": uuid.uuid4().hex, "url": verified, "name": "Community Source",
                  "enabled": True, "official": False}
        records = self.read_source(source)
        if not records:
            raise InvalidSource("The source contains no valid iPhone app listings.")
        source["name"] = self._source_title(verified)
        self.sources.append(source)
        self.save()
        return source

    @staticmethod
    def _source_title(url: str) -> str:
        return urllib.parse.urlsplit(url).hostname or "Community"

    def remove(self, source_id: str):
        self.sources = [s for s in self.sources if s["id"] != source_id]
        self.community_apps = [a for a in self.community_apps if a["source_id"] != source_id]
        self.save()

    def set_enabled(self, source_id: str, enabled: bool):
        for source in self.sources:
            if source["id"] == source_id:
                source["enabled"] = enabled
        self.save()

    def read_source(self, source: dict) -> list[dict]:
        raw = retrieve(source["url"], 450_000)
        try:
            doc = json.loads(raw)
        except (ValueError, UnicodeDecodeError) as exc:
            raise InvalidSource("Source must provide UTF-8 JSON.") from exc
        rows = doc.get("apps") if isinstance(doc, dict) else None
        if not isinstance(rows, list) or len(rows) > 200 or doc.get("schema_version") != 1:
            raise InvalidSource("Unsupported source schema or more than 200 app listings.")
        apps = []
        for entry in rows:
            if not isinstance(entry, dict):
                continue
            app_id = str(entry.get("id", ""))
            bundle = str(entry.get("bundle_id", ""))
            download = str(entry.get("download_url", ""))
            if not SAFE_ID.fullmatch(app_id) or "." not in bundle or len(bundle) > 240:
                continue
            try:
                link = public_https(download)
                if not urllib.parse.urlsplit(link).path.lower().endswith(".ipa"):
                    continue
            except (ValueError, TypeError):
                continue
            image = str(entry.get("icon_url", ""))
            try:
                image = public_https(image) if image else ""
            except (ValueError, TypeError):
                image = ""
            apps.append({
                "id": source["id"] + "::" + app_id, "app_id": app_id,
                "name": str(entry.get("name", "Untitled"))[:120],
                "description": str(entry.get("description", ""))[:300],
                "category": str(entry.get("category", "Apps"))[:70],
                "version": str(entry.get("version", "Preview"))[:100],
                "developer": str(entry.get("developer", source["name"]))[:100],
                "bundle_id": bundle, "download_url": link, "icon_url": image,
                "source_name": source["name"], "source_id": source["id"],
                "official": False, "requires_signing": bool(entry.get("requires_signing", True))
            })
        return apps

    def refresh(self) -> tuple[list[dict], list[str]]:
        apps = []
        errors = []
        for source in self.sources:
            if not source["enabled"]:
                continue
            try:
                apps += self.read_source(source)
            except (OSError, ValueError) as exc:
                errors.append(source["name"] + ": " + str(exc))
        self.community_apps = apps
        return self.items(), errors

    def items(self) -> list[dict]:
        # The official source uses a separate constant immutable ID, so a
        # community source cannot overwrite its listings.
        try:
            official = self.official.refresh()
        except (OSError, ValueError, RuntimeError):
            official = []
        originals = [{
            "id": "itamaros-official::" + a["id"], "app_id": a["id"],
            "name": a["name"], "description": a["description"],
            "category": "Apps" if a.get("category") == "System" else
                        self._official_category(a["id"]),
            "version": a["release_tag"], "developer": "ItamarOS",
            "bundle_id": a["bundle_id"], "download_url": a["url"],
            "icon_url": "", "source_name": "ItamarOS Official",
            "source_id": "itamaros-official", "official": True,
            "requires_signing": True
        } for a in official]
        return originals + list(self.community_apps)

    @staticmethod
    def _official_category(app_id: str) -> str:
        categories = {
            "CloudClimbiOS": "Games", "ItamarOSGamesiOS": "Games",
            "SkyboundIslesiOS": "Games", "ArenaRushiOS": "Games",
            "ItamarCutiOS": "Creative", "VoiceRecorderiOS": "Creative",
            "BrowserOSiOS": "Utilities", "ScreenBalanceiOS": "Utilities",
            "ItamarOS-Authenticator": "Security", "ItamarOS-Installer": "Utilities",
        }
        return categories.get(app_id, "Apps")

    def download(self, item: dict) -> tuple[Path, bool]:
        if item["official"]:
            return self.official.download(item["app_id"])
        allowed = next((a for a in self.community_apps if a["id"] == item["id"]), None)
        if allowed is None:
            raise InvalidSource("Community source is disabled or no longer available.")
        # Stream untrusted IPA downloads in bounded chunks. Never allocate
        # an entire potentially multi-gigabyte IPA in RAM.
        checked = public_https(allowed["download_url"])
        resolve_public_host(checked)
        destination_dir = BASE_DIR / "CommunityDownloads"
        destination_dir.mkdir(parents=True, exist_ok=True)
        with tempfile.NamedTemporaryFile(suffix=".ipa", dir=destination_dir, delete=False) as tmp:
            path = Path(tmp.name)
        try:
            req = urllib.request.Request(
                checked, headers={"User-Agent": "ItamarOS-Store/1.0"})
            with urllib.request.build_opener(HTTPSOnlyRedirect).open(req, timeout=120) as response:
                total = 0
                with path.open("wb") as out:
                    while chunk := response.read(256 * 1024):
                        total += len(chunk)
                        if total > MAX_IPA:
                            raise InvalidSource("Community IPA exceeds the 2 GB limit.")
                        out.write(chunk)
            # Verify the IPA structure and declared Bundle ID. This is not
            # a code-signing or malware security review.
            signed = OfficialCatalog._inspect(path, allowed["bundle_id"])
            final = destination_dir / (allowed["source_id"] + "-" + allowed["app_id"] + ".ipa")
            path.replace(final)
            return final, signed
        except Exception:
            path.unlink(missing_ok=True)
            raise
