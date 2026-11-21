"""Offline tests for official + community ItamarOS Store sources."""
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from store_sources import CommunitySources, InvalidSource, public_https


class FakeOfficial:
    folder = Path("unused")
    def refresh(self):
        return [
            {"id": "BrowserOSiOS", "name": "BrowserOS", "description": "Native browser",
             "bundle_id": "org.itamaros.browseros", "release_tag": "ios-browseros-test",
             "url": "https://github.com/itamarnintendo04-arch/ItamarOS/releases/download/ios-browseros-test/BrowserOS-UNSIGNED.ipa"},
            {"id": "ItamarCutiOS", "name": "ItamarCut", "description": "Video editor",
             "bundle_id": "org.itamaros.cut", "release_tag": "ios-itamarcut-test",
             "url": "https://github.com/itamarnintendo04-arch/ItamarOS/releases/download/ios-itamarcut-test/Cut-UNSIGNED.ipa"},
            {"id": "CloudClimbiOS", "name": "Cloud Climb", "description": "Game",
             "bundle_id": "org.itamaros.cloudclimb", "release_tag": "ios-cloudclimb-test",
             "url": "https://github.com/itamarnintendo04-arch/ItamarOS/releases/download/ios-cloudclimb-test/Cloud-UNSIGNED.ipa"},
        ]


class CommunitySourceTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.store = CommunitySources(FakeOfficial(), Path(self.tmp.name) / "sources.json")

    def test_official_source_contains_regular_apps_and_games(self):
        items = self.store.items()
        self.assertEqual(len(items), 3)
        self.assertTrue(all(i["official"] for i in items))
        self.assertEqual([a["category"] for a in items], ["Apps", "Creative", "Games"])

    def test_disallow_private_urls_and_credentials(self):
        for url in ["http://example.com/source.json", "https://localhost/catalog.json",
                    "https://127.0.0.1/apps.json", "https://192.168.1.10/apps.json",
                    "https://user:password@example.com/apps.json", "https://example.local/apps.json",
                    "https://example.com:8080/apps.json"]:
            with self.subTest(url=url), self.assertRaises(InvalidSource):
                public_https(url)
        self.assertEqual(public_https("https://example.com/apps.json"),
                         "https://example.com/apps.json")

    def test_custom_source_can_never_mark_itself_official(self):
        data = {
            "schema_version": 1, "name": "Fake Official",
            "apps": [{"id": "BrowserOSiOS", "name": "Imposter", "description": "Example",
                      "category": "Utilities", "bundle_id": "org.imposter.browser",
                      "download_url": "https://example.com/Imposter.ipa", "official": True}]
        }
        with patch("store_sources.retrieve", return_value=json.dumps(data).encode()):
            item = self.store.add("https://example.com/apps.json")
            self.assertFalse(item["official"])
            merged, problems = self.store.refresh()
        self.assertEqual(problems, [])
        # The immutable official BrowserOS is retained and cannot be overwritten
        # by a community source sharing its public app ID.
        items = self.store.items()
        self.assertTrue(any(a["id"] == "itamaros-official::BrowserOSiOS" for a in items))
        self.assertTrue(all(a["official"] for a in items if a["source_id"] == "itamaros-official"))
        self.assertFalse(any(a["official"] for a in items if a["source_id"] != "itamaros-official"))

    def test_invalid_and_oversized_catalog_rejected(self):
        for obj in [{"schema_version": 2, "apps": []}, {"schema_version": 1, "apps": [0] * 201}]:
            with patch("store_sources.retrieve", return_value=json.dumps(obj).encode()):
                with self.assertRaises(InvalidSource):
                    self.store.add("https://example.com/apps.json")

    def test_toggle_and_remove_preserve_official(self):
        data = {
            "schema_version": 1,
            "apps": [{"id": "tinyapp", "name": "Tiny App", "description": "Demo",
                      "bundle_id": "com.example.tiny", "category": "Utilities",
                      "download_url": "https://example.com/tiny.ipa"}]
        }
        with patch("store_sources.retrieve", return_value=json.dumps(data).encode()):
            source = self.store.add("https://example.com/apps.json")
        self.store.set_enabled(source["id"], False)
        self.assertFalse(self.store.sources[0]["enabled"])
        self.store.remove(source["id"])
        self.assertEqual(self.store.sources, [])
        self.assertEqual(len(self.store.items()), 3)


if __name__ == "__main__":
    unittest.main()
