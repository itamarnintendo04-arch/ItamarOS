"""First-party main-repository app registry and on-demand official IPA downloads.

No user-supplied URL or arbitrary filesystem path is accepted; all download
URLs are built from the bundled official main-repository release catalog.
"""
from __future__ import annotations

import hashlib
import json
import os
import plistlib
import re
import sys
import tempfile
import time
import urllib.request
import zipfile
from pathlib import Path

BASE = "https://github.com/itamarnintendo04-arch/ItamarOS/releases/download/"
REGISTRY = "https://raw.githubusercontent.com/itamarnintendo04-arch/ItamarOS/main/catalog/ios-apps.json"
MAX_IPA = 2_000_000_000
SAFE = re.compile(r"^[A-Za-z0-9._-]{2,150}$")


class OfficialCatalog:
    def __init__(self, catalog_path: Path | None = None, folder: Path | None = None):
        root = Path(getattr(sys, "_MEIPASS", Path(__file__).resolve().parent))
        self.catalog_path = catalog_path or (root / "resources/official-ios-apps.json")
        self.folder = folder or (Path(os.environ.get("LOCALAPPDATA", Path.home()))
                                 / "ItamarOS Installer" / "Downloads")
        self._apps: dict[str, dict] = {}
        self._updated = 0.0

    def _validate(self, data: object) -> dict[str, dict]:
        if not isinstance(data, dict) or data.get("schema_version") != 1:
            raise ValueError("Expected the official ItamarOS catalog format.")
        rows = data.get("apps")
        if not isinstance(rows, list) or len(rows) > 100:
            raise ValueError("Official catalog must have no more than 100 applications.")
        apps = {}
        for row in rows:
            if not isinstance(row, dict):
                raise ValueError("Unexpected app entry.")
            app_id = str(row.get("id", ""))
            tag = str(row.get("release_tag", ""))
            asset = str(row.get("asset_name", ""))
            bundle = str(row.get("bundle_id", ""))
            if not all(SAFE.fullmatch(x) for x in (app_id, tag, asset)):
                raise ValueError("Official catalog contains an invalid identifier.")
            if not asset.lower().endswith(".ipa") or not re.fullmatch(r"[A-Za-z0-9.-]{3,240}", bundle):
                raise ValueError("Official catalog references an unexpected bundle or asset.")
            apps[app_id] = {
                "id": app_id, "name": str(row.get("name", app_id))[:120],
                "description": str(row.get("description", ""))[:240],
                "bundle_id": bundle,
                "release_tag": tag, "asset_name": asset,
                "signed": "unsigned" not in asset.casefold(),
                "url": BASE + tag + "/" + asset,
            }
        return apps

    def refresh(self, force: bool = False) -> list[dict]:
        now = time.monotonic()
        if self._apps and not force and now - self._updated < 20 * 60:
            return self.list_apps()
        try:
            request = urllib.request.Request(REGISTRY, headers={"User-Agent": "ItamarOS-Installer/2.2"})
            with urllib.request.urlopen(request, timeout=10) as response:
                data = response.read(260_000)
            apps = self._validate(json.loads(data))
        except (OSError, ValueError, json.JSONDecodeError):
            if self._apps:
                return self.list_apps()
            if not self.catalog_path.is_file():
                raise RuntimeError("Official catalog is unavailable and no bundled copy was found.")
            apps = self._validate(json.loads(self.catalog_path.read_text(encoding="utf-8")))
        self._apps = apps
        self._updated = now
        return self.list_apps()

    def list_apps(self) -> list[dict]:
        # Send only public release metadata; never expose local filesystem paths.
        return [dict(row) for row in sorted(self._apps.values(), key=lambda x: x["name"].lower())]

    def get(self, app_id: str) -> dict:
        if not self._apps:
            self.refresh()
        app = self._apps.get(app_id)
        if app is None:
            raise ValueError("Unknown official ItamarOS application.")
        return dict(app)

    def download(self, app_id: str) -> tuple[Path, bool]:
        app = self.get(app_id)
        self.folder.mkdir(parents=True, exist_ok=True)
        output = self.folder / app["asset_name"]
        # Safe to reuse only after validating the expected Bundle ID.
        if output.is_file():
            try:
                signed = self._inspect(output, app["bundle_id"])
                return output, signed
            except (OSError, ValueError, zipfile.BadZipFile):
                output.unlink(missing_ok=True)

        fd, tempname = tempfile.mkstemp(prefix=".official-", suffix=".ipa", dir=self.folder)
        os.close(fd)
        path = Path(tempname)
        try:
            request = urllib.request.Request(app["url"], headers={"User-Agent": "ItamarOS-Installer/2.2"})
            with urllib.request.urlopen(request, timeout=120) as src, path.open("wb") as dst:
                total = 0
                while chunk := src.read(256 * 1024):
                    total += len(chunk)
                    if total > MAX_IPA:
                        raise ValueError("Official IPA exceeds 2 GB.")
                    dst.write(chunk)
            signed = self._inspect(path, app["bundle_id"])
            os.replace(path, output)
            return output, signed
        except Exception:
            path.unlink(missing_ok=True)
            raise

    @staticmethod
    def _inspect(path: Path, bundle: str) -> bool:
        with zipfile.ZipFile(path) as archive:
            names = archive.namelist()
            infolist = [i for i in archive.infolist()
                        if re.fullmatch(r"Payload/[^/]+\.app/Info\.plist", i.filename)]
            if len(infolist) != 1 or infolist[0].file_size > 1_000_000:
                raise ValueError("IPA is missing a valid app Info.plist.")
            info = plistlib.loads(archive.read(infolist[0]))
            if info.get("CFBundleIdentifier") != bundle:
                raise ValueError("Downloaded IPA Bundle ID does not match the official catalog.")
            return any(re.fullmatch(r"Payload/[^/]+\.app/_CodeSignature/CodeResources", x)
                       for x in names)
