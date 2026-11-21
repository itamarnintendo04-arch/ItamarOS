"""Tests for desktop-only certificate import and public iPhone sync metadata."""
import datetime as dt
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import desktop_certificates as module
from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives.serialization import pkcs12
from cryptography.x509.oid import NameOID


class DesktopCertificateTests(unittest.TestCase):
    def test_import_metadata_only_and_remove_without_erasing_certificate(self):
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            key = ec.generate_private_key(ec.SECP256R1())
            now = dt.datetime.now(dt.timezone.utc)
            subject = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, "Test ItamarOS Identity")])
            cert = (x509.CertificateBuilder().subject_name(subject).issuer_name(subject)
                    .public_key(key.public_key()).serial_number(x509.random_serial_number())
                    .not_valid_before(now - dt.timedelta(days=1))
                    .not_valid_after(now + dt.timedelta(days=30))
                    .sign(key, hashes.SHA256()))
            raw = pkcs12.serialize_key_and_certificates(
                b"test", key, cert, None,
                serialization.BestAvailableEncryption(b"testpassword"))
            p12_path = folder / "identity.p12"
            p12_path.write_bytes(raw)
            with patch.object(module, "ROOT", folder), patch.object(module, "REGISTRY", folder / "certs.json"):
                vault = module.DesktopCertificates()
                cert_record = vault.import_identity(str(p12_path), "testpassword")
                metadata = vault.public_list()
                self.assertTrue(vault.contains_available(cert_record["id"]))
                self.assertEqual(len(metadata), 1)
                self.assertNotIn("p12_path", metadata[0])
                self.assertNotIn("password", metadata[0])
                self.assertNotIn("testpassword", (folder / "certs.json").read_text())
                with self.assertRaises(ValueError):
                    vault.import_identity(str(p12_path), "wrongpassword")
                vault.remove(cert_record["id"])
                self.assertEqual(vault.public_list(), [])
                self.assertTrue(p12_path.exists())


if __name__ == "__main__":
    unittest.main()
