"""Tests for opt-in encrypted iPhone Wi-Fi companion pairing and access control."""
import json
import ssl
import time
import unittest
import urllib.error
import urllib.request

from lan_bridge import CompanionServer


class LANBridgeTests(unittest.TestCase):
    def setUp(self):
        self.seen = []
        self.server = CompanionServer(
            get_devices=lambda: [{"name": "Test iPhone", "udid": "TEST-DEVICE-01234567"}],
            get_apps=lambda: [{"id": "OfficialExampleiOS", "name": "Example",
                               "signed": False, "bundle_id": "org.itamaros.example"}],
            on_request=self.seen.append,
            host="127.0.0.1",
            port=0
        )
        self.server.start()
        self.base = f"https://127.0.0.1:{self.server.port}"
        self.context = ssl._create_unverified_context()  # Test only; mobile uses TLS fingerprint pin.

    def tearDown(self):
        self.server.stop()

    def request(self, path, payload=None, token=None):
        headers = {}
        if token:
            headers["X-ItamarOS-Session"] = token
        if payload is not None:
            headers["Content-Type"] = "application/json"
            data = json.dumps(payload).encode()
        else:
            data = None
        request = urllib.request.Request(
            self.base + path, data=data,
            headers=headers, method="POST" if data is not None else "GET")
        try:
            with urllib.request.urlopen(request, context=self.context, timeout=5) as r:
                return r.status, json.load(r)
        except urllib.error.HTTPError as exc:
            return exc.code, json.load(exc)

    def test_public_health_but_private_device_details(self):
        status, value = self.request("/health")
        self.assertEqual(status, 200)
        self.assertTrue(value["pairing_required"])
        self.assertEqual(self.request("/v1/devices")[0], 401)
        self.assertEqual(self.request("/v1/apps")[0], 401)

    def test_pairing_limits_and_install_requires_desktop_approval(self):
        self.assertEqual(self.request("/v1/pair", {"code": "00000000"})[0], 403)
        code = self.server.pair_code
        status, result = self.request("/v1/pair", {"code": code})
        self.assertEqual(status, 200)
        session = result["session"]
        self.assertNotEqual(code, self.server.pair_code)
        self.assertEqual(self.request("/v1/devices", token=session)[1]["devices"][0]["name"], "Test iPhone")
        self.assertEqual(len(self.request("/v1/apps", token=session)[1]["apps"]), 1)
        self.assertEqual(self.request("/v1/request-install",
                                      {"app_id": "unofficial", "udid": "TEST-DEVICE-01234567"},
                                      session)[0], 400)
        status, queued = self.request("/v1/request-install",
                                      {"app_id": "OfficialExampleiOS", "udid": "TEST-DEVICE-01234567"},
                                      session)
        self.assertEqual(status, 202)
        self.assertEqual(queued["state"], "waiting_for_desktop_approval")
        self.assertEqual(len(self.seen), 1)
        self.server.finish_request(queued["request_id"], "requires_signing",
                                   "Unsigned official preview")
        result = self.request("/v1/requests/" + queued["request_id"], token=session)[1]
        self.assertEqual(result["request"]["state"], "requires_signing")

    def test_code_expires_and_rate_limits(self):
        with self.server.guard:
            self.server.expires_at = time.monotonic() - 1
        self.assertEqual(self.request("/v1/pair", {"code": self.server.pair_code})[0], 403)
        for _ in range(4):
            self.request("/v1/pair", {"code": "00000000"})
        self.assertEqual(self.request("/v1/pair", {"code": "00000000"})[0], 429)


if __name__ == "__main__":
    unittest.main()
