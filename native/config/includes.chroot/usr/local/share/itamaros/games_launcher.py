#!/usr/bin/env python3
"""Serve only bundled static ItamarOS games on localhost for persistent browser saves."""
from __future__ import annotations
import mimetypes
import subprocess
import sys
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

HOST = "127.0.0.1"
PORT = 17893
ROOT = Path("/usr/local/share/itamaros")
FILES = {"games-extra.html", "games.js", "more-games.js", "games.css"}
MARKER = "ItamarOS Games localhost 1.1"
URL = f"http://{HOST}:{PORT}/games-extra.html"

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        route = self.path.split("?", 1)[0].lstrip("/")
        if route == "__itamaro_health":
            payload = MARKER.encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.send_header("Content-Length", str(len(payload)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(payload)
            return
        if route not in FILES:
            self.send_error(404, "Not found")
            return
        file = ROOT / route
        try:
            data = file.read_bytes()
        except OSError:
            self.send_error(404, "Asset missing")
            return
        self.send_response(200)
        self.send_header("Content-Type", mimetypes.guess_type(route)[0] or "application/octet-stream")
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-cache")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("X-Frame-Options", "DENY")
        self.end_headers()
        self.wfile.write(data)

def healthy_existing() -> bool:
    try:
        with urllib.request.urlopen(f"http://{HOST}:{PORT}/__itamaro_health", timeout=1) as response:
            return response.status == 200 and response.read(100).decode() == MARKER
    except (urllib.error.URLError, OSError, UnicodeError):
        return False

def open_browser() -> None:
    subprocess.Popen(["xdg-open", URL], start_new_session=True)

def main():
    try:
        server = ThreadingHTTPServer((HOST, PORT), Handler)
    except OSError:
        if healthy_existing():
            open_browser()
            return
        print("ItamarOS Games port 17893 is busy with another process. Refusing to use it.", file=sys.stderr)
        sys.exit(1)
    open_browser()
    try:
        server.serve_forever(poll_interval=0.5)
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()

if __name__ == "__main__":
    main()
