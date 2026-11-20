import json
import tempfile
import unittest
import zipfile
from pathlib import Path

from catalog_native import native_rows, ios_target_blocks, TARGETS

from installer_core import (
    CatalogApp, InstallerError, catalog_from_repos, friendly_error, inspect_ipa,
    parse_devices, safe_filename, download_ipa
)

OWNER = "itamarnintendo04-arch"

class InstallerTests(unittest.TestCase):
    def setUp(self):
        self.repo = {
            "name": "ItamarOS-Authenticator",
            "topics": [], "fork": False, "archived": False,
            "description": "2FA app",
            "html_url": "https://github.com/" + OWNER + "/ItamarOS-Authenticator"
        }
    def test_actual_native_catalog(self):
        spec = (Path(__file__).resolve().parents[3] / "native-apps" / "apple" / "project.yml").read_text(encoding="utf-8")
        native = native_rows(spec)
        names = {app["name"] for app in native}
        self.assertGreaterEqual(len(native), 9)
        self.assertEqual(len(native), len(names))
        self.assertTrue({"Cloud Climb", "ItamarOS", "ItamarCut", "BrowserOS", "Voice Recorder", "ItamarOS Games", "Arena Rush", "Skybound Isles", "ItamarOS Screen Balance"}.issubset(names))
        for app in native:
            self.assertTrue(app["repository_url"].startswith("https://github.com/itamarnintendo04-arch/"))
            self.assertTrue(app["icon_slug"])
            self.assertEqual(app["source_kind"], "native_ios")

    def test_signed_release(self):
        release = {"tag_name": "v1.5", "assets": [
            {"name": "unsigned.ipa", "browser_download_url":
                "https://github.com/" + OWNER + "/ItamarOS-Authenticator/releases/download/v1.5/unsigned.ipa"},
            {"name": "signed.ipa", "browser_download_url":
                "https://github.com/" + OWNER + "/ItamarOS-Authenticator/releases/download/v1.5/signed.ipa"}
        ]}
        apps = catalog_from_repos([self.repo], lambda _: release)
        self.assertEqual(apps[0].version, "v1.5")
        self.assertTrue(apps[0].installable())
        self.assertTrue(apps[0].ipa_url.endswith("signed.ipa"))
    def test_unsigned_release_blocked(self):
        release = {"tag_name": "v1", "assets": [
            {"name": "app-unsigned.ipa",
             "browser_download_url": "https://github.com/" + OWNER +
             "/ItamarOS-Authenticator/releases/download/v1/app-unsigned.ipa"}]}
        self.assertFalse(catalog_from_repos([self.repo],lambda _: release)[0].installable())
    def test_untrusted_link_blocked(self):
        release = {"tag_name": "v1", "assets": [
            {"name": "app.ipa", "browser_download_url": "https://example.org/app.ipa"}]}
        self.assertFalse(catalog_from_repos([self.repo],lambda _: release)[0].installable())
    def test_topic_discovers_new_app(self):
        repo = {"name":"NewGame","topics":["itamaros-ios"],"archived":False,"fork":False}
        self.assertEqual(len(catalog_from_repos([repo],lambda _: {})), 1)
    def test_fork_excluded(self):
        self.assertEqual(catalog_from_repos([dict(self.repo, fork=True)],lambda _: {}),[])
    def test_ipa_verification(self):
        with tempfile.TemporaryDirectory() as directory:
            archive = Path(directory) / "app.ipa"
            with zipfile.ZipFile(archive, "w") as z:
                z.writestr("Payload/Test.app/Info.plist",b"plist")
            self.assertFalse(inspect_ipa(archive)[0])
            with zipfile.ZipFile(archive, "a") as z:
                z.writestr("Payload/Test.app/_CodeSignature/CodeResources",b"test")
            self.assertTrue(inspect_ipa(archive)[0])
    def test_filename_safe(self):
        app = CatalogApp(name="x",repo="../../evil",version="../../v1")
        self.assertNotIn("/",safe_filename(app))
    def test_device_json(self):
        value = json.dumps([{"DeviceID": 1, "Properties":{"SerialNumber":"00008030-000ABC123456"}}])
        self.assertEqual(parse_devices(value)[0]["udid"], "00008030-000ABC123456")
    def test_signature_error(self):
        self.assertIn("signature",friendly_error("ApplicationVerificationFailed").lower())
    def test_download_disallows_other_hosts(self):
        app=CatalogApp(name="app",repo="x",version="1",ipa_url="https://example.org/x.ipa")
        with tempfile.TemporaryDirectory() as d:
            with self.assertRaises(InstallerError): download_ipa(app,Path(d))
if __name__ == "__main__":
    unittest.main()
