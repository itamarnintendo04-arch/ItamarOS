"""Catalog, download, USB device and IPA installation services for ItamarOS Installer."""
from __future__ import annotations

import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
import zipfile
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Callable
from catalog_native import native_rows, read_project_yaml, icon_for_repository

OWNER = "itamarnintendo04-arch"
AGENT = "ItamarOS-Installer/1.0 (+https://github.com/itamarnintendo04-arch/ItamarOS)"
API = "https://api.github.com"
MAX_IPA_BYTES = 2 * 1024 * 1024 * 1024
CACHE_SECONDS = 1200
APP_ROOT = Path(os.environ.get("LOCALAPPDATA", Path.home())) / "ItamarOS Installer"
DOWNLOAD_DIR = APP_ROOT / "Downloads"
KNOWN_REPOS = {"ItamarOS-Authenticator"}


@dataclass(frozen=True)
class CatalogApp:
    name: str
    repo: str
    description: str = ""
    version: str = "Not released"
    ipa_url: str = ""
    release_url: str = ""
    published: str = ""
    size_bytes: int = 0
    expected_sha256: str = ""
    repository_url: str = ""
    category: str = "Apps"
    icon_url: str = ""
    icon_slug: str = ""
    bundle_id: str = ""
    source_kind: str = "repository"
    def installable(self) -> bool:
        return bool(self.ipa_url)


class InstallerError(Exception):
    """Show this message in the user-facing error dialog."""


def friendly_error(raw: str) -> str:
    s = (raw or "").lower()
    if "pair" in s or "trust" in s or "lockdownd" in s:
        return "Your iPhone isn't trusted yet. Unlock it, tap Trust This Computer, and reconnect."
    if "no device" in s or "not found" in s or "couldn't connect" in s or "connection refused" in s:
        return "No compatible iPhone was detected. Check the USB cable and Apple Mobile Device Service."
    if "code signature" in s or "applicationverificationfailed" in s or "0xe800801" in s:
        return "iOS rejected the app signature. This IPA must be signed for this iPhone with a valid provisioning profile."
    if "developer mode" in s:
        return "Developer Mode is required for this development-signed app. Check Settings > Privacy & Security on your iPhone."
    if "provision" in s or "profile" in s:
        return "The provisioning profile does not permit installation on this iPhone."
    if "access denied" in s or "permission" in s:
        return "Windows blocked access. Check permissions and make sure Apple's device service is running."
    if "timed out" in s or "timeout" in s:
        return "The operation timed out. Reconnect and unlock your iPhone, then try again."
    if "rate limit" in s or "403" in s:
        return "GitHub's public API rate limit was reached. Try refreshing again later."
    if "http error 404" in s:
        return "This release or repository is unavailable. It may have been removed or made private."
    return "Operation failed: " + (raw.strip()[:500] or "Unknown error")


def api_json(path: str, opener=urllib.request.urlopen) -> object:
    if not path.startswith("/") or "://" in path:
        raise ValueError("Expected a GitHub API path.")
    request = urllib.request.Request(API + path, headers={
        "Accept": "application/vnd.github+json", "User-Agent": AGENT,
        "X-GitHub-Api-Version": "2022-11-28",
    })
    try:
        with opener(request, timeout=22) as response:
            return json.loads(response.read(8 * 1024 * 1024).decode("utf-8"))
    except urllib.error.HTTPError as exc:
        if exc.code == 404:
            raise InstallerError("GitHub resource not found.") from exc
        if exc.code in (403, 429):
            raise InstallerError("GitHub API rate limit or access restriction.") from exc
        raise InstallerError(f"GitHub returned HTTP {exc.code}.") from exc
    except (OSError, ValueError) as exc:
        raise InstallerError(f"Unable to refresh catalog: {exc}") from exc


def catalog_from_repos(repositories: list[dict], release_lookup: Callable[[str], dict | None]) -> list[CatalogApp]:
    apps: list[CatalogApp] = []
    for repo in repositories:
        name = str(repo.get("name", ""))
        topics = repo.get("topics") or []
        if repo.get("fork") or repo.get("archived"):
            continue
        if not (name in KNOWN_REPOS or name.lower().endswith("-ios") or "itamaros-ios" in topics):
            continue
        try:
            release = release_lookup(name) or {}
        except InstallerError:
            release = {}
        assets = release.get("assets") or []
        # Prefer a clearly signed IPA over an unsigned, un-installable build.
        eligible = [a for a in assets if str(a.get("name", "")).lower().endswith(".ipa") and "unsigned" not in str(a.get("name", "")).lower()]
        eligible.sort(key=lambda a: (
            "unsigned" not in str(a.get("name", "")).lower(),
            bool(a.get("digest")),
            str(a.get("updated_at", "")),
        ), reverse=True)
        item = eligible[0] if eligible else {}
        digest = str(item.get("digest") or "")
        sha = digest[7:] if re.fullmatch(r"sha256:[0-9a-fA-F]{64}", digest) else ""
        ipa = str(item.get("browser_download_url") or "")
        if ipa and (not ipa.startswith(f"https://github.com/{OWNER}/") or "unsigned" in str(item.get("name", "")).lower()):
            ipa = ""  # Never offer unverified third-party or explicitly unsigned packages as installable.
        image_url, image_slug = icon_for_repository(name)
        apps.append(CatalogApp(
            name=("ItamarOS Authenticator" if name == "ItamarOS-Authenticator" else str(repo.get("name", "")).replace("-", " ")),
            repo=name,
            description=str(repo.get("description") or "Official ItamarOS project."),
            version=str(release.get("tag_name") or "Not released"),
            ipa_url=ipa,
            release_url=str(release.get("html_url") or ""),
            published=str(release.get("published_at") or ""),
            size_bytes=int(item.get("size", 0)) if ipa else 0,
            expected_sha256=sha if ipa else "",
            repository_url=str(repo.get("html_url") or f"https://github.com/{OWNER}/{name}"),
            category="Security" if name == "ItamarOS-Authenticator" else "Apps",
            icon_url=image_url,
            icon_slug=image_slug,
        ))
    apps.sort(key=lambda item: (not item.installable(), item.name.lower()))
    return apps


class GitHubCatalog:
    def __init__(self, root: Path = APP_ROOT) -> None:
        self.root = root
        self.file = root / "catalog-cache.json"
    def _repositories(self) -> list[dict]:
        results = []
        for page in range(1, 6):
            chunk = api_json(f"/users/{OWNER}/repos?per_page=100&page={page}&type=owner&sort=updated")
            if not isinstance(chunk, list):
                raise InstallerError("GitHub returned unexpected repository data.")
            results.extend(chunk)
            if len(chunk) < 100:
                break
        return results
    def refresh(self, force: bool = False) -> list[CatalogApp]:
        if not force and self.file.exists() and time.time() - self.file.stat().st_mtime < CACHE_SECONDS:
            try:
                cached = json.loads(self.file.read_text(encoding="utf-8"))
                return [CatalogApp(**item) for item in cached]
            except (ValueError, TypeError):
                pass
        def release_for(name: str) -> dict | None:
            try:
                response = api_json(f"/repos/{OWNER}/{urllib.parse.quote(name)}/releases/latest")
                return response if isinstance(response, dict) else None
            except InstallerError:
                return None
        apps = catalog_from_repos(self._repositories(), release_for)
        try:
            spec = read_project_yaml(api_json)
            release = release_for("ItamarOS")
            native = [CatalogApp(**row) for row in native_rows(spec, release)]
            # Deduplicate source-defined apps against stand-alone repositories.
            native_names = {item.name.casefold() for item in native}
            apps = native + [app for app in apps if app.name.casefold() not in native_names]
        except (InstallerError, ValueError, KeyError, TypeError) as exc:
            # Preserve the verified public repository list if the source project is offline.
            if not apps:
                raise InstallerError("ItamarOS app catalog could not load: " + str(exc)) from exc
        apps.sort(key=lambda app: (not app.installable(), app.category, app.name.lower()))
        self.root.mkdir(parents=True, exist_ok=True)
        self.file.write_text(json.dumps([asdict(a) for a in apps], indent=2), encoding="utf-8")
        return apps


def safe_filename(app: CatalogApp) -> str:
    slug = re.sub(r"[^a-zA-Z0-9_.-]", "_", f"{app.repo}-{app.icon_slug or app.name}-{app.version}")
    return slug[:180] + ".ipa"


def inspect_ipa(path: Path) -> tuple[bool, str]:
    try:
        with zipfile.ZipFile(path, "r") as ipa:
            names = ipa.namelist()
            if not any(re.fullmatch(r"Payload/[^/]+\.app/Info\.plist", p) for p in names):
                return False, "Invalid IPA: Payload/*.app/Info.plist is missing."
            if not any(re.fullmatch(r"Payload/[^/]+\.app/_CodeSignature/CodeResources", p) for p in names):
                return False, "This IPA is unsigned. Sign it for your iPhone before installing."
            return True, "The IPA contains a code signature (device verification still required)."
    except (OSError, zipfile.BadZipFile) as exc:
        return False, "This download is not a valid IPA archive: " + str(exc)


def download_ipa(app: CatalogApp, folder: Path = DOWNLOAD_DIR, on_progress: Callable[[float], None] | None = None,
                 opener=urllib.request.urlopen) -> Path:
    if not app.installable():
        raise InstallerError("There is no published signed IPA for this app yet.")
    url = urllib.parse.urlparse(app.ipa_url)
    if url.scheme != "https" or url.hostname != "github.com" or not url.path.startswith(f"/{OWNER}/"):
        raise InstallerError("Only official ItamarOS GitHub release downloads are accepted.")
    folder.mkdir(parents=True, exist_ok=True)
    output = folder / safe_filename(app)
    if output.exists():
        if app.expected_sha256:
            with output.open("rb") as handle:
                existing = hashlib.file_digest(handle, "sha256").hexdigest()
            if existing.lower() == app.expected_sha256.lower():
                good, _ = inspect_ipa(output)
                if good:
                    return output
        else:
            good, _ = inspect_ipa(output)
            if good:
                return output
    fd, temporary = tempfile.mkstemp(prefix=".itamaros-", suffix=".ipa", dir=folder)
    os.close(fd)
    digest = hashlib.sha256()
    try:
        request = urllib.request.Request(app.ipa_url, headers={"User-Agent": AGENT})
        with opener(request, timeout=90) as remote, open(temporary, "wb") as local:
            total = int(remote.headers.get("Content-Length") or app.size_bytes or 0)
            copied = 0
            while True:
                chunk = remote.read(256 * 1024)
                if not chunk:
                    break
                copied += len(chunk)
                if copied > MAX_IPA_BYTES:
                    raise InstallerError("IPA exceeds the maximum permitted size (2 GB).")
                digest.update(chunk)
                local.write(chunk)
                if on_progress and total:
                    on_progress(min(copied / total, 1.0))
        if app.expected_sha256 and digest.hexdigest().lower() != app.expected_sha256.lower():
            raise InstallerError("Download checksum mismatch. The IPA was discarded for safety.")
        good, explanation = inspect_ipa(Path(temporary))
        if not good:
            raise InstallerError(explanation)
        os.replace(temporary, output)
        return output
    except Exception:
        Path(temporary).unlink(missing_ok=True)
        raise


def mobile_device_service_running() -> bool | None:
    if sys.platform != "win32":
        return None
    flags = getattr(subprocess, "CREATE_NO_WINDOW", 0)
    try:
        result = subprocess.run(["sc.exe", "query", "Apple Mobile Device Service"],
                                text=True, capture_output=True, timeout=8, creationflags=flags)
        return result.returncode == 0 and bool(re.search(r"STATE\s*:\s*4\s+RUNNING", result.stdout))
    except (OSError, subprocess.TimeoutExpired):
        return False


def command_for_device_tool() -> list[str] | None:
    executable = shutil.which("pymobiledevice3")
    if executable:
        return [executable]
    # A frozen executable cannot run a Python module by spawning itself.
    if not getattr(sys, "frozen", False):
        try:
            import importlib.util
            if importlib.util.find_spec("pymobiledevice3"):
                return [sys.executable, "-m", "pymobiledevice3"]
        except (ImportError, ValueError):
            pass
    # Windows user scripts install location
    if sys.platform == "win32":
        for item in (Path.home() / "AppData" / "Roaming" / "Python").glob("Python*/Scripts/pymobiledevice3.exe"):
            if item.is_file():
                return [str(item)]
    return None


def run_device_tool(args: list[str], *, timeout: int = 30,
                    runner: Callable = subprocess.run) -> str:
    command = command_for_device_tool()
    if command is None:
        raise InstallerError("Device helper missing. Install Python and run: py -m pip install --user pymobiledevice3. Then restart ItamarOS Installer.")
    flags = getattr(subprocess, "CREATE_NO_WINDOW", 0)
    try:
        result = runner([*command, *args], capture_output=True, text=True,
                        encoding="utf-8", errors="replace", timeout=timeout,
                        creationflags=flags)
    except subprocess.TimeoutExpired as exc:
        raise InstallerError("The iPhone did not respond in time. Unlock it and reconnect.") from exc
    except OSError as exc:
        raise InstallerError("Could not launch iOS device helper: " + str(exc)) from exc
    if result.returncode:
        raise InstallerError(friendly_error((result.stderr or result.stdout).strip()))
    return result.stdout


def parse_devices(output: str) -> list[dict[str, str]]:
    try:
        data = json.loads(output)
    except (TypeError, json.JSONDecodeError):
        raise InstallerError("The iPhone helper returned an unreadable device list.")
    if isinstance(data, dict):
        data = data.get("devices", data.get("Devices", []))
    if not isinstance(data, list):
        raise InstallerError("Unexpected device list format.")
    devices = []
    for item in data:
        if not isinstance(item, dict):
            continue
        properties = item.get("Properties") or item.get("properties") or {}
        uid = str(item.get("udid") or item.get("serial") or item.get("SerialNumber")
                  or properties.get("SerialNumber") or properties.get("UDID") or "")
        name = str(item.get("DeviceName") or item.get("name") or properties.get("DeviceName")
                   or properties.get("ProductType") or "Connected iPhone")
        if uid and re.fullmatch(r"[a-zA-Z0-9-]{8,80}", uid):
            devices.append({"udid": uid, "name": name})
    return devices


def scan_devices() -> list[dict[str, str]]:
    return parse_devices(run_device_tool(["usbmux", "list"], timeout=15))


def install_ipa(path: Path, udid: str) -> str:
    if not re.fullmatch(r"[A-Za-z0-9-]{8,80}", udid):
        raise InstallerError("No valid target iPhone selected.")
    good, explanation = inspect_ipa(path)
    if not good:
        raise InstallerError(explanation)
    # --udid explicitly targets the selected connected iPhone.
    return run_device_tool(["apps", "install", "--udid", udid, str(path)], timeout=600)
