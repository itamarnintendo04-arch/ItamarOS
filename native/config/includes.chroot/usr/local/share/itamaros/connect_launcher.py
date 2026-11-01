#!/usr/bin/env python3
"""ItamarConnect launcher for the experimental ItamarOS native Linux image.

No tokens are passed in URL parameters or extracted from browser cookies.
The remote website runs only when the independent messaging backend exists.
"""
from __future__ import annotations
import shutil
import subprocess
import sys

CONNECT_URL = "https://itamaros-web-emulator.onrender.com/connect.html"
BROWSERS = ("chromium", "chromium-browser", "google-chrome", "brave-browser")


def main() -> int:
    for browser in BROWSERS:
        program = shutil.which(browser)
        if program:
            try:
                subprocess.Popen([program, "--app=" + CONNECT_URL, "--no-first-run"],
                                 start_new_session=True)
                return 0
            except OSError as exc:
                print("Cannot open Connect:", exc, file=sys.stderr)
                return 1
    opener = shutil.which("xdg-open")
    if opener:
        subprocess.Popen([opener, CONNECT_URL], start_new_session=True)
        return 0
    print("No browser is installed. Install Chromium through the package manager.", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
