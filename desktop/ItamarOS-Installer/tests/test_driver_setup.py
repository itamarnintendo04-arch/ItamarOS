"""Driver setup stays available and installs from the official Microsoft Store only."""
import subprocess
import unittest
from unittest.mock import patch

import driver_setup


class DriverSetupTests(unittest.TestCase):
    @patch.object(driver_setup.sys, "platform", "win32")
    def test_detects_installed_apple_devices(self):
        def runner(command, timeout):
            if command[0] == "sc.exe":
                return subprocess.CompletedProcess(command, 1, "", "")
            return subprocess.CompletedProcess(command, 0, "AppleInc.AppleDevices\n", "")
        status = driver_setup.check_drivers(runner=runner, which=lambda name: None)
        self.assertTrue(status.ready)
        self.assertTrue(status.apple_devices_app)
        self.assertEqual(status.service, "missing")
        self.assertFalse(status.winget_available)

    @patch.object(driver_setup.sys, "platform", "win32")
    def test_detects_running_service(self):
        def runner(command, timeout):
            if command[0] == "sc.exe":
                return subprocess.CompletedProcess(command, 0, "STATE : 4 RUNNING", "")
            return subprocess.CompletedProcess(command, 0, "", "")
        status = driver_setup.check_drivers(runner=runner, which=lambda name: "winget.exe")
        self.assertEqual(status.service, "running")
        self.assertTrue(status.ready)

    @patch.object(driver_setup.sys, "platform", "win32")
    def test_install_uses_exact_microsoft_store_product(self):
        executed = []
        def runner(command, timeout):
            executed.append((command, timeout))
            return subprocess.CompletedProcess(command, 0, "", "")
        result = driver_setup.install_apple_devices(runner=runner, which=lambda name: "winget.exe")
        self.assertTrue(result[0])
        argv, timeout = executed[0]
        self.assertEqual(argv[:4], ["winget.exe", "install", "--exact", "--id"])
        self.assertIn(driver_setup.APPLE_DEVICES_STORE_ID, argv)
        self.assertIn("msstore", argv)
        self.assertEqual(timeout, 600)

    @patch.object(driver_setup.sys, "platform", "win32")
    def test_without_winget_does_not_install(self):
        result = driver_setup.install_apple_devices(which=lambda name: None)
        self.assertFalse(result[0])
        self.assertIn("winget", result[1])

    def test_official_store_url_is_https(self):
        self.assertEqual(
            driver_setup.APPLE_DEVICES_STORE_URL,
            "https://apps.microsoft.com/detail/9NP83LWLPZ9K",
        )


if __name__ == "__main__":
    unittest.main()
