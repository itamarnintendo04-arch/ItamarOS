"""No-root native code smoke tests; never partition or install anything."""
import json
import sys
import unittest
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "native/config/includes.chroot/usr/local/share/itamaros"
sys.path.insert(0, str(SOURCE))
sys.path.insert(0, str(ROOT / "native"))
from hardware import detect, human_size, vendor_label, device_category
import update_check
from version import next_version

class NativeSmoke(unittest.TestCase):
    def test_hardware_probe_is_safe_and_typed(self):
        inventory = detect()
        self.assertIn("cpu", inventory)
        self.assertIn("manufacturer", inventory)
        self.assertIn("model", inventory)
        self.assertIsInstance(inventory["ram_bytes"], int)
        self.assertIsInstance(inventory["storage"], list)
        self.assertIsInstance(inventory["cores_logical"], int)
        self.assertEqual(vendor_label("Dell Inc."), "Dell")
        self.assertEqual(vendor_label("LENOVO"), "Lenovo")
        self.assertEqual(vendor_label("Hewlett-Packard"), "HP")
        self.assertEqual(human_size(2147483648), "2.0 GiB")

    def test_versions(self):
        self.assertEqual([next_version(v) for v in ("1.1", "1.5", "1.9", "2.1")],
                         ["1.5", "1.9", "2.1", "2.5"])
        self.assertGreater(update_check.version_tuple("1.5"), update_check.version_tuple("1.1"))
        with self.assertRaises(ValueError):
            next_version("1.2")

    def test_no_false_native_update_when_source_only(self):
        with mock.patch.object(update_check, "get_remote", return_value={
            "schemaVersion": 1, "version": "1.5", "components": [],
            "releaseStatus": "source-preview", "installers": [],
        }):
            info = update_check.check()
            self.assertTrue(info["ok"])
            self.assertFalse(info["update_available"])
            self.assertTrue(info["source_preview_only"])

    def test_native_manifests_are_valid(self):
        native = json.loads((ROOT / "updates/native-stable.json").read_text())
        self.assertEqual(native["version"], "1.1")
        self.assertEqual(native["installers"], [])
        self.assertEqual(native["releaseStatus"], "source-preview")
        self.assertEqual(native["sequence"][:4], ["1.1", "1.5", "1.9", "2.1"])
        self.assertTrue((ROOT / "native/config/includes.chroot/usr/share/applications/itamaros-control-center.desktop").exists())

if __name__ == "__main__":
    unittest.main()
