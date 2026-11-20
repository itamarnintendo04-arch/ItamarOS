"""Unit tests for official GitHub-only app package selection and IPA verification."""
import json
import plistlib
import tempfile
import unittest
import zipfile
from pathlib import Path

from official_catalog import OfficialCatalog


class OfficialCatalogTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.folder = Path(self.tmp.name)
        self.service = OfficialCatalog(self.folder / "registry.json", self.folder / "downloads")

    def example(self):
        return {"schema_version": 1, "apps": [
            {"id": "SafeiOS", "name": "Safe", "bundle_id": "org.itamaros.safe",
             "release_tag": "ios-safe-v1.0-preview", "asset_name": "Safe-UNSIGNED.ipa"}
        ]}

    def test_catalog_url_is_first_party_only(self):
        apps = self.service._validate(self.example())
        self.assertTrue(apps["SafeiOS"]["url"].startswith(
            "https://github.com/itamarnintendo04-arch/ItamarOS/releases/download/"))
        self.assertFalse(apps["SafeiOS"]["signed"])

    def test_disallow_asset_traversal(self):
        bad = self.example()
        bad["apps"][0]["asset_name"] = "../../private.p12"
        with self.assertRaises(ValueError):
            self.service._validate(bad)

    def test_inspect_requires_matching_app_bundle(self):
        archive = self.folder / "test.ipa"
        metadata = {"CFBundleIdentifier": "org.itamaros.safe",
                    "CFBundleShortVersionString": "1.0"}
        with zipfile.ZipFile(archive, "w") as z:
            z.writestr("Payload/Safe.app/Info.plist",
                       plistlib.dumps(metadata))
        self.assertFalse(self.service._inspect(archive, "org.itamaros.safe"))
        with self.assertRaises(ValueError):
            self.service._inspect(archive, "org.itamaros.unknown")

    def test_signed_marker_only_structure_not_trust(self):
        archive = self.folder / "signed-structure.ipa"
        with zipfile.ZipFile(archive, "w") as z:
            z.writestr("Payload/Safe.app/Info.plist",
                       plistlib.dumps({"CFBundleIdentifier": "org.itamaros.safe"}))
            z.writestr("Payload/Safe.app/_CodeSignature/CodeResources", b"placeholder")
        # Marker detection is not cryptographic proof; Apple's device services
        # are responsible for signature and provisioning enforcement.
        self.assertTrue(self.service._inspect(archive, "org.itamaros.safe"))


if __name__ == "__main__":
    unittest.main()
