"""Tests for safe multi-ZIP certificate extraction and password TXT previews."""
import os
import stat
import tempfile
import unittest
import zipfile
from pathlib import Path

from certificate_archives import extract_archives


class CertificateArchiveTests(unittest.TestCase):
    def test_multiple_zip_files_and_txt_not_persisted(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            first, second = root / "one.zip", root / "two.zip"
            with zipfile.ZipFile(first, "w") as z:
                z.writestr("certs/first.p12", b"fake p12 A")
                z.writestr("certs/first.mobileprovision", b"fake profile A")
                z.writestr("notes/password.txt", "Password: local secret A".encode("utf-8"))
            with zipfile.ZipFile(second, "w") as z:
                z.writestr("second.p12", b"fake p12 B")
                z.writestr("password.txt", "Password: local secret B".encode("utf-16"))
            entries = extract_archives([str(first), str(second)], root / "vault")
            self.assertEqual(len(entries), 2)
            self.assertTrue(entries[0].profile_path.endswith(".mobileprovision"))
            self.assertFalse(entries[1].profile_path)
            self.assertEqual(entries[0].txt_notes[0][1], "Password: local secret A")
            self.assertEqual(entries[1].txt_notes[0][1], "Password: local secret B")
            self.assertEqual(Path(entries[0].p12_path).read_bytes(), b"fake p12 A")
            self.assertEqual(Path(entries[1].p12_path).read_bytes(), b"fake p12 B")
            self.assertFalse(list((root / "vault").rglob("*.txt")))
            self.assertNotIn("local secret A", str(list((root / "vault").rglob("*"))))

    def test_zip_slip_paths_are_not_used(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            archive_path = root / "traversal.zip"
            with zipfile.ZipFile(archive_path, "w") as z:
                z.writestr("../../outside.p12", b"certificate")
                z.writestr("..\\..\\outside.txt", b"hint")
            results = extract_archives([str(archive_path)], root / "private")
            self.assertEqual(len(results), 1)
            self.assertTrue(Path(results[0].p12_path).resolve().is_relative_to((root / "private").resolve()))
            self.assertFalse((root / "outside.p12").exists())

    def test_zip_with_large_txt_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            archive_path = root / "bad.zip"
            with zipfile.ZipFile(archive_path, "w", zipfile.ZIP_DEFLATED) as z:
                z.writestr("file.p12", b"certificate")
                z.writestr("password.txt", b"x" * 20000)
            with self.assertRaises(ValueError):
                extract_archives([str(archive_path)], root / "vault")

    def test_symlink_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            archive_path = root / "link.zip"
            link = zipfile.ZipInfo("evil.p12")
            link.create_system = 3
            link.external_attr = (stat.S_IFLNK | 0o777) << 16
            with zipfile.ZipFile(archive_path, "w") as z:
                z.writestr(link, "outside")
            with self.assertRaises(ValueError):
                extract_archives([str(archive_path)], root / "vault")

    def test_missing_p12_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            archive_path = root / "notes.zip"
            with zipfile.ZipFile(archive_path, "w") as z:
                z.writestr("password.txt", b"irrelevant")
            with self.assertRaises(ValueError):
                extract_archives([str(archive_path)], root / "vault")


if __name__ == "__main__":
    unittest.main()
