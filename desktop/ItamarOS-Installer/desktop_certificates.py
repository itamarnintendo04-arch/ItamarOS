"""Local-only signing identity registry. Never sends a P12, key or password over Wi-Fi."""
from __future__ import annotations

import datetime as dt
import json
import os
import uuid
from pathlib import Path

ROOT = Path(os.environ.get("LOCALAPPDATA", str(Path.home() / ".config"))) / "ItamarOS" / "Installer"
REGISTRY = ROOT / "desktop-certificates.json"


class DesktopCertificates:
    def __init__(self):
        self._entries = self._load()

    def _load(self):
        try:
            value = json.loads(REGISTRY.read_text(encoding="utf-8"))
            return value if isinstance(value, list) else []
        except (OSError, ValueError):
            return []

    def _save(self):
        ROOT.mkdir(parents=True, exist_ok=True)
        tmp = REGISTRY.with_suffix(".tmp")
        tmp.write_text(json.dumps(self._entries, indent=2), encoding="utf-8")
        if os.name != "nt":
            tmp.chmod(0o600)
        tmp.replace(REGISTRY)

    def import_identity(self, p12_path: str, password: str, profile_path: str = "") -> dict:
        """Validate the PKCS#12 and remember its LOCAL file path, not its password."""
        from cryptography.hazmat.primitives.serialization import pkcs12
        from cryptography.hazmat.primitives import hashes
        p12 = Path(p12_path).resolve(strict=True)
        if p12.suffix.lower() != ".p12" or p12.stat().st_size > 20_000_000:
            raise ValueError("Choose a P12 certificate smaller than 20 MB.")
        key, cert, _ = pkcs12.load_key_and_certificates(p12.read_bytes(), password.encode("utf-8"))
        if key is None or cert is None:
            raise ValueError("The P12 must contain a signing identity and private key.")
        profile = ""
        if profile_path:
            pp = Path(profile_path).resolve(strict=True)
            if pp.suffix.lower() != ".mobileprovision" or pp.stat().st_size > 5_000_000:
                raise ValueError("Choose a provisioning profile smaller than 5 MB.")
            profile = str(pp)
        expiry = cert.not_valid_after_utc.isoformat()
        fingerprint = cert.fingerprint(hashes.SHA256()).hex()
        name = cert.subject.rfc4514_string()[:160]
        previous = next((x for x in self._entries if x["fingerprint"] == fingerprint), None)
        record = {"id": previous["id"] if previous else uuid.uuid4().hex,
                  "name": name, "expires": expiry, "fingerprint": fingerprint,
                  "has_profile": bool(profile), "p12_path": str(p12), "profile_path": profile}
        self._entries = [x for x in self._entries if x["id"] != record["id"]]
        self._entries.append(record)
        self._save()
        return record

    def remove(self, identity_id: str):
        self._entries = [x for x in self._entries if x["id"] != identity_id]
        self._save()

    def public_list(self) -> list[dict]:
        now = dt.datetime.now(dt.timezone.utc)
        out = []
        for item in self._entries:
            try:
                expiry = dt.datetime.fromisoformat(item["expires"])
                available = expiry > now and Path(item["p12_path"]).is_file() and (
                    not item["profile_path"] or Path(item["profile_path"]).is_file())
            except (KeyError, ValueError, TypeError):
                available = False
            out.append({"id": item["id"], "name": item["name"],
                        "expires": item["expires"], "has_profile": item["has_profile"],
                        "available": available})
        return out

    def contains_available(self, identity_id: str) -> bool:
        return any(x["id"] == identity_id and x["available"] for x in self.public_list())
