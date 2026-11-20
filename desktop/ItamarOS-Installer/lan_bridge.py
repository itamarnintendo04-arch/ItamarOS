"""Opt-in, short-lived, TLS-pinned local iPhone companion server.

The Windows app exposes a read-only first-party catalog and selected paired
iPhone metadata on the LOCAL LAN. The companion must prove the 8-digit pairing
code over a TLS connection whose certificate fingerprint is pinned from QR.

No P12 files, provisioning private keys, passwords, Apple accounts or arbitrary
filesystem paths are accepted, stored or served.

Apple Wi-Fi Sync is separate: it is only a transport option for Apple's own
pairing/device services and does not grant an iPhone app install permissions.
"""
from __future__ import annotations

import datetime as dt
import hashlib
import ipaddress
import json
import queue
import secrets
import socket
import ssl
import tempfile
import threading
import time
from dataclasses import dataclass
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Callable
from urllib.parse import urlencode

HOST = "0.0.0.0"
MAX_BODY = 4096
EXPIRATION = 600
SERVICE_TYPE = "_itamaros._tcp.local."


def local_ipv4() -> str:
    """Resolve an actual routable LAN address; do not publish a public IP."""
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        sock.connect(("192.0.2.1", 80))  # route lookup only; no packet is sent
        address = sock.getsockname()[0]
        if ipaddress.ip_address(address).is_private:
            return address
    except OSError:
        pass
    finally:
        sock.close()
    for entry in socket.getaddrinfo(socket.gethostname(), 0, family=socket.AF_INET):
        ip = entry[4][0]
        if ipaddress.ip_address(ip).is_private and not ip.startswith("127."):
            return ip
    return "127.0.0.1"


def make_ephemeral_tls() -> tuple[ssl.SSLContext, str]:
    from cryptography import x509
    from cryptography.hazmat.primitives import hashes, serialization
    from cryptography.hazmat.primitives.asymmetric import ec
    from cryptography.x509.oid import NameOID

    key = ec.generate_private_key(ec.SECP256R1())
    now = dt.datetime.now(dt.timezone.utc)
    cert = (
        x509.CertificateBuilder()
        .subject_name(x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, "ItamarOS LAN Installer")]))
        .issuer_name(x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, "ItamarOS LAN Installer")]))
        .public_key(key.public_key())
        .serial_number(x509.random_serial_number())
        .not_valid_before(now - dt.timedelta(minutes=1))
        .not_valid_after(now + dt.timedelta(days=2))
        .sign(key, hashes.SHA256())
    )
    der = cert.public_bytes(serialization.Encoding.DER)
    fingerprint = hashlib.sha256(der).hexdigest()
    cert_pem = cert.public_bytes(serialization.Encoding.PEM)
    private_pem = key.private_bytes(serialization.Encoding.PEM,
                                   serialization.PrivateFormat.PKCS8,
                                   serialization.NoEncryption())
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.minimum_version = ssl.TLSVersion.TLSv1_2
    with tempfile.TemporaryDirectory(prefix="itamaros-tls-") as directory:
        cert_file = Path(directory) / "cert.pem"
        key_file = Path(directory) / "key.pem"
        cert_file.write_bytes(cert_pem)
        key_file.write_bytes(private_pem)
        context.load_cert_chain(str(cert_file), str(key_file))
    return context, fingerprint


@dataclass(frozen=True)
class InstallRequest:
    id: str
    app_id: str
    target_udid: str
    created_at: float


class CompanionServer:
    def __init__(self, get_devices: Callable[[], list[dict]],
                 get_apps: Callable[[], list[dict]],
                 on_request: Callable[[InstallRequest], None],
                 host: str = HOST, port: int = 0):
        self.get_devices = get_devices
        self.get_apps = get_apps
        self.on_request = on_request
        self.host = host
        self.port = port
        self.fingerprint = ""
        self.pair_code = ""
        self.expires_at = 0.0
        self.sessions: dict[str, float] = {}
        self.failed_attempts: dict[str, list[float]] = {}
        self.requests: dict[str, dict] = {}
        self.guard = threading.RLock()
        self.httpd: ThreadingHTTPServer | None = None
        self.thread: threading.Thread | None = None
        self.zeroconf = None
        self.service_info = None
        self.rotate_code()

    def rotate_code(self) -> None:
        with self.guard:
            self.pair_code = str(secrets.randbelow(90_000_000) + 10_000_000)
            self.expires_at = time.monotonic() + EXPIRATION

    @property
    def pairing_url(self) -> str:
        ip = local_ipv4()
        query = urlencode({"host": ip, "port": self.port, "code": self.pair_code,
                           "fp": self.fingerprint})
        return "itamaros://pair?" + query

    def start(self) -> None:
        if self.httpd is not None:
            return
        context, self.fingerprint = make_ephemeral_tls()
        owner = self

        class Handler(BaseHTTPRequestHandler):
            server_version = "ItamarOSCompanion/1.0"

            def log_message(self, *args):
                return  # Never log pairing codes, device IDs or session tokens.

            def _json(self, code: int, payload: dict) -> None:
                data = json.dumps(payload, separators=(",", ":")).encode("utf-8")
                self.send_response(code)
                self.send_header("Content-Type", "application/json; charset=utf-8")
                self.send_header("Content-Length", str(len(data)))
                self.send_header("Cache-Control", "no-store")
                self.send_header("X-Content-Type-Options", "nosniff")
                self.end_headers()
                self.wfile.write(data)

            def _authenticated(self) -> bool:
                token = self.headers.get("X-ItamarOS-Session", "")
                now = time.monotonic()
                with owner.guard:
                    expiry = owner.sessions.get(token, 0)
                    if expiry > now and token:
                        owner.sessions[token] = now + 3600
                        return True
                self._json(401, {"error": "pairing_required"})
                return False

            def _read_json(self) -> dict | None:
                try:
                    amount = int(self.headers.get("Content-Length", "0"))
                except (TypeError, ValueError):
                    amount = -1
                if not (1 <= amount <= MAX_BODY):
                    self._json(413, {"error": "invalid_request_size"})
                    return None
                try:
                    payload = json.loads(self.rfile.read(amount))
                except (UnicodeDecodeError, json.JSONDecodeError):
                    self._json(400, {"error": "bad_json"})
                    return None
                if not isinstance(payload, dict):
                    self._json(400, {"error": "bad_request"})
                    return None
                return payload

            def do_GET(self):
                path = self.path.split("?")[0]
                if path == "/health":
                    self._json(200, {"name": "ItamarOS Installer", "protocol": 1,
                                     "pairing_required": True})
                    return
                if not self._authenticated():
                    return
                if path == "/v1/devices":
                    # Only trusted/paired local Apple devices known to desktop.
                    devices = owner.get_devices()
                    self._json(200, {"devices": [
                        {"name": str(d.get("name", ""))[:120],
                         "udid": str(d.get("udid", ""))[:80]}
                        for d in devices if d.get("udid")
                    ]})
                elif path == "/v1/apps":
                    self._json(200, {"apps": owner.get_apps()[:50]})
                elif path.startswith("/v1/requests/"):
                    key = path.removeprefix("/v1/requests/")
                    with owner.guard:
                        result = owner.requests.get(key)
                    if result is None:
                        self._json(404, {"error": "request_not_found"})
                    else:
                        self._json(200, {"request": result})
                else:
                    self._json(404, {"error": "not_found"})

            def do_POST(self):
                data = self._read_json()
                if data is None:
                    return
                path = self.path.split("?")[0]
                if path == "/v1/pair":
                    client = self.client_address[0]
                    now = time.monotonic()
                    with owner.guard:
                        failures = [v for v in owner.failed_attempts.get(client, []) if now - v < 600]
                        if len(failures) >= 5:
                            self._json(429, {"error": "too_many_attempts"})
                            return
                        good = now < owner.expires_at and secrets.compare_digest(
                            str(data.get("code", "")), owner.pair_code
                        )
                        if not good:
                            failures.append(now)
                            owner.failed_attempts[client] = failures
                            self._json(403, {"error": "invalid_pairing_code"})
                            return
                        token = secrets.token_urlsafe(32)
                        owner.sessions[token] = now + 3600
                        owner.rotate_code()
                    self._json(200, {"session": token, "expires_in": 3600})
                    return
                if not self._authenticated():
                    return
                if path != "/v1/request-install":
                    self._json(404, {"error": "not_found"})
                    return
                app_id = str(data.get("app_id", ""))
                udid = str(data.get("udid", ""))
                if len(app_id) > 100 or len(udid) > 80:
                    self._json(400, {"error": "invalid_arguments"})
                    return
                allowed = {str(a.get("id", "")) for a in owner.get_apps()}
                paired = {str(d.get("udid", "")) for d in owner.get_devices()}
                if app_id not in allowed or udid not in paired:
                    self._json(400, {"error": "unknown_app_or_device"})
                    return
                request = InstallRequest(secrets.token_urlsafe(16), app_id, udid, time.time())
                with owner.guard:
                    owner.requests[request.id] = {"id": request.id, "app_id": app_id,
                                                  "state": "waiting_for_desktop_approval"}
                owner.on_request(request)
                self._json(202, {"request_id": request.id, "state": "waiting_for_desktop_approval"})

        self.httpd = ThreadingHTTPServer((self.host, self.port), Handler)
        self.port = self.httpd.server_address[1]
        self.httpd.socket = context.wrap_socket(self.httpd.socket, server_side=True)
        self.thread = threading.Thread(target=self.httpd.serve_forever, daemon=True,
                                       name="ItamarOS TLS LAN Companion")
        self.thread.start()
        self._advertise()

    def _advertise(self) -> None:
        try:
            from zeroconf import IPVersion, ServiceInfo, Zeroconf
            ip = local_ipv4()
            if ip == "127.0.0.1":
                return
            info = ServiceInfo(
                SERVICE_TYPE, "ItamarOS Installer._itamaros._tcp.local.",
                addresses=[socket.inet_aton(ip)], port=self.port,
                properties={"version": "1", "tls": "fingerprint-pinned"}
            )
            zc = Zeroconf(ip_version=IPVersion.V4Only)
            zc.register_service(info)
            self.zeroconf, self.service_info = zc, info
        except Exception:
            # Manual QR/address pairing still works when mDNS is blocked.
            self.zeroconf = None
            self.service_info = None

    def finish_request(self, request_id: str, state: str, detail: str = "") -> None:
        if state not in {"denied", "downloading", "requires_signing", "installed", "failed"}:
            raise ValueError("Invalid operation status.")
        with self.guard:
            if request_id in self.requests:
                self.requests[request_id].update(
                    state=state, detail=detail[:320]
                )

    def stop(self) -> None:
        if self.zeroconf and self.service_info:
            self.zeroconf.unregister_service(self.service_info)
            self.zeroconf.close()
        self.zeroconf = None
        if self.httpd:
            self.httpd.shutdown()
            self.httpd.server_close()
            self.httpd = None
        with self.guard:
            self.sessions.clear()
            self.requests.clear()
