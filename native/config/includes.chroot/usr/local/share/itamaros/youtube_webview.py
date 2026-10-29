#!/usr/bin/env python3
"""Launch the official YouTube website as a separate browser app window.

Uses the system browser in application mode. No embedded downloader,
cookie extraction, third-party API impersonation, or DRM bypass.
"""
from __future__ import annotations
import shutil
import subprocess
import sys

SITE = "https://www.youtube.com/"
BROWSERS = ("chromium", "chromium-browser", "google-chrome", "brave-browser")

def main() -> int:
    for name in BROWSERS:
        executable = shutil.which(name)
        if executable:
            try:
                subprocess.Popen(
                    [executable, "--app=" + SITE, "--no-first-run"],
                    start_new_session=True
                )
                return 0
            except OSError as exc:
                print(f"Browser launch failed: {exc}", file=sys.stderr)
                return 1
    fallback = shutil.which("xdg-open")
    if fallback:
        subprocess.Popen([fallback, SITE], start_new_session=True)
        return 0
    print("No compatible browser installed. Install Chromium using Software Center.", file=sys.stderr)
    return 1

if __name__ == "__main__":
    raise SystemExit(main())
