#!/usr/bin/env python3
"""ItamarOS native update checker — download only metadata, never run binaries."""
from __future__ import annotations
import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

MANIFEST = "https://raw.githubusercontent.com/itamarnintendo04-arch/ItamarOS/main/updates/native-stable.json"
INSTALLED = Path("/usr/local/share/itamaros/version.json")
CACHE = Path.home() / ".cache" / "itamaros" / "update_state.json"

def version_tuple(version: str) -> tuple:
    if not re.fullmatch(r"\d+\.\d+(?:\.\d+)?", str(version)):
        raise ValueError("Invalid version")
    return tuple(int(p) for p in (str(version) + ".0").split(".")[:3])

def installed_version() -> str:
    try:
        return str(json.loads(INSTALLED.read_text())["version"])
    except (OSError, ValueError, KeyError):
        return "1.1"

def get_remote() -> dict:
    req = urllib.request.Request(
        MANIFEST, headers={"User-Agent": "ItamarOS-native-update-check/1.1",
                           "Accept": "application/json", "Cache-Control": "no-cache"})
    with urllib.request.urlopen(req, timeout=12) as response:
        if response.status != 200:
            raise ValueError(f"Unexpected HTTP status {response.status}")
        if int(response.headers.get("Content-Length", "0") or "0") > 100000:
            raise ValueError("Update manifest exceeds size limit")
        data = response.read(100001)
        if len(data) > 100000:
            raise ValueError("Update manifest exceeds size limit")
    manifest = json.loads(data)
    if not isinstance(manifest, dict) or manifest.get("schemaVersion") != 1:
        raise ValueError("Invalid update manifest schema")
    version_tuple(manifest["version"])
    if not isinstance(manifest.get("components"), list):
        raise ValueError("Invalid component list")
    return manifest

def check() -> dict:
    local = installed_version()
    try:
        manifest = get_remote()
        newest = manifest["version"]
        new = version_tuple(newest) > version_tuple(local)
        downloadable = manifest.get("releaseStatus") == "released" and bool(manifest.get("installers"))
        return {
            "ok": True, "installed": local, "latest": newest,
            "update_available": bool(new and downloadable),
            "source_preview_only": bool(new and not downloadable),
            "status": manifest.get("releaseStatus", "unknown"),
            "notes": manifest.get("notes", [])[:10],
            "checked_at": int(time.time()),
        }
    except (OSError, KeyError, TypeError, ValueError, urllib.error.URLError) as exc:
        return {"ok": False, "error": str(exc), "installed": local,
                "checked_at": int(time.time())}

def notify(title: str, message: str) -> None:
    tool = shutil.which("notify-send")
    if tool:
        try:
            subprocess.run([tool, "--app-name=ItamarOS", "--icon=software-update-available",
                            title, message], timeout=8, check=False)
        except (OSError, subprocess.TimeoutExpired):
            pass

def write_cache(info: dict) -> None:
    try:
        CACHE.parent.mkdir(parents=True, exist_ok=True)
        CACHE.write_text(json.dumps(info, indent=2), encoding="utf-8")
    except OSError:
        pass

def gui():
    import tkinter as tk
    from tkinter import ttk
    root = tk.Tk()
    root.title("ItamarOS Software Updates")
    root.geometry("570x400")
    frame = ttk.Frame(root, padding=20)
    frame.pack(fill="both", expand=True)
    ttk.Label(frame, text="Software Updates", font=("Sans", 18, "bold")).pack(anchor="w")
    ttk.Label(frame, text="System software updates use Debian's signed package repositories.",
              wraplength=520).pack(anchor="w", pady=10)
    status = tk.Text(frame, height=12, wrap="word", state="disabled")
    status.pack(fill="both", expand=True)
    def set_text(s: str):
        status.configure(state="normal")
        status.delete("1.0", "end")
        status.insert("end", s)
        status.configure(state="disabled")
    def refresh():
        result = check()
        write_cache(result)
        if not result["ok"]:
            set_text("Update check failed: " + result["error"])
        elif result["update_available"]:
            set_text(f"New ItamarOS version {result['latest']} available!\n"
                     "View official release notes and supported installers before proceeding.")
        elif result["source_preview_only"]:
            set_text(f"Version {result['latest']} exists as source preview only. "
                     "No tested native installer is published.")
        else:
            set_text(f"Installed ItamarOS: {result['installed']}\n"
                     f"Latest published metadata: {result['latest']}\n"
                     "No installable OS image is available.\n\n"
                     "Use Discover for normal app and security updates.")
    buttons = ttk.Frame(frame)
    buttons.pack(fill="x", pady=15)
    ttk.Button(buttons, text="Check for updates", command=refresh).pack(side="left", padx=4)
    ttk.Button(buttons, text="Install system & app updates", command=open_discover).pack(side="left", padx=4)
    ttk.Button(buttons, text="Remind me later", command=root.destroy).pack(side="right", padx=4)
    refresh()
    root.mainloop()

def open_discover() -> None:
    executable = shutil.which("plasma-discover")
    if executable:
        subprocess.Popen([executable], start_new_session=True)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--gui", action="store_true")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()
    if args.gui:
        gui()
        return
    previous = {}
    try:
        previous = json.loads(CACHE.read_text())
    except (OSError, ValueError):
        pass
    result = check()
    write_cache(result)
    if args.json:
        print(json.dumps(result, indent=2))
    if result.get("update_available") and (
        previous.get("latest") != result.get("latest") or
        not previous.get("update_available")
    ):
        notify("ItamarOS update is available",
               f"Version {result['latest']} — open Software Updates for details")
    if result.get("ok") is False and args.json:
        sys.exit(1)

if __name__ == "__main__":
    main()
