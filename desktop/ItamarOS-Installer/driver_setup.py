"""Windows-only, opt-in Apple device driver setup through Microsoft Store.

No third-party driver archives, unsigned binaries or privileged scripts are
downloaded by this application. Apple's official Apple Devices Store listing
is used. This does not replace iPhone Trust pairing or the IPA helper.
"""
from __future__ import annotations

import shutil
import subprocess
import sys
import webbrowser
from dataclasses import dataclass
from typing import Callable

APPLE_DEVICES_STORE_ID = "9NP83LWLPZ9K"
APPLE_DEVICES_STORE_URL = "https://apps.microsoft.com/detail/" + APPLE_DEVICES_STORE_ID


@dataclass(frozen=True)
class DriverStatus:
    service: str
    apple_devices_app: bool
    winget_available: bool

    @property
    def ready(self) -> bool:
        # A running legacy driver service, or the modern Apple Devices app,
        # indicates Apple software is present. Neither guarantees iPhone pairing.
        return self.service == "running" or self.apple_devices_app


def _run(command: list[str], timeout: int = 15) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command, capture_output=True, text=True, encoding="utf-8",
        errors="replace", timeout=timeout,
        creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
    )


def check_drivers(runner: Callable = _run, which: Callable = shutil.which) -> DriverStatus:
    """Inspect Windows driver prerequisites without changing system settings."""
    if sys.platform != "win32":
        return DriverStatus("unsupported", False, False)
    service = "missing"
    try:
        info = runner(["sc.exe", "query", "Apple Mobile Device Service"], 12)
        if info.returncode == 0:
            service = "running" if "RUNNING" in info.stdout.upper() else "stopped"
    except (OSError, subprocess.TimeoutExpired):
        service = "unavailable"
    modern_app = False
    try:
        command = [
            "powershell.exe", "-NoProfile", "-NonInteractive", "-Command",
            "(Get-AppxPackage -Name 'AppleInc.AppleDevices' -ErrorAction SilentlyContinue | "
            "Select-Object -First 1 -ExpandProperty Name)"
        ]
        result = runner(command, 16)
        modern_app = result.returncode == 0 and "AppleInc.AppleDevices" in result.stdout
    except (OSError, subprocess.TimeoutExpired):
        pass
    return DriverStatus(service, modern_app, bool(which("winget")))


def install_apple_devices(runner: Callable = _run, which: Callable = shutil.which) -> tuple[bool, str]:
    """Install the official Microsoft Store listing after the user approved it.

    winget uses Microsoft's msstore source and an exact immutable product ID.
    Callers should offer the official Store page when winget is unavailable.
    """
    if sys.platform != "win32":
        return False, "Apple Devices installation is supported on Windows only."
    winget = which("winget")
    if not winget:
        return False, "Windows Package Manager (winget) is unavailable."
    command = [
        winget, "install", "--exact", "--id", APPLE_DEVICES_STORE_ID,
        "--source", "msstore", "--accept-source-agreements",
        "--accept-package-agreements",
    ]
    try:
        result = runner(command, 600)
    except subprocess.TimeoutExpired:
        return False, "The Microsoft Store installation did not finish in time."
    except OSError as error:
        return False, "Could not launch Windows Package Manager: " + str(error)
    if result.returncode == 0:
        return True, "Apple Devices installation command completed. Reconnect your iPhone and recheck drivers."
    detail = (result.stderr or result.stdout or "").strip()
    return False, ("Microsoft Store installation failed. " + detail[-350:]).strip()


def open_official_store(opener: Callable = webbrowser.open) -> bool:
    return bool(opener(APPLE_DEVICES_STORE_URL))
