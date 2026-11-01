from __future__ import annotations

import io
import json
import shutil
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from app import ScaleHardwareAdapter, start_api_server
import urllib.request

ROOT = Path(__file__).resolve().parents[2]
SOURCE_DB = ROOT / "database" / "miqdar_nutrition.db"


class ScaleHardwareAndApiTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp_dir = Path(tempfile.mkdtemp(prefix="scale-test-"))
        self.db_path = self.temp_dir / "test.db"
        shutil.copy2(SOURCE_DB, self.db_path)
        self._env = patch.dict("os.environ", {"MIQDAR_RECOGNITION_PROVIDER": "mock"})
        self._env.start()
        self.hw = ScaleHardwareAdapter(force_mock=True)
        self.hw.analyze_on_scale = True
        self.hw.start()

    def tearDown(self) -> None:
        self.hw.stop()
        self._env.stop()
        shutil.rmtree(self.temp_dir)

    def test_hardware_adapter_operations(self) -> None:
        self.assertTrue(self.hw.is_mock)
        self.assertEqual(self.hw.get_weight(), 0.0)

        # Simulate putting 200g on the scale
        self.hw.set_sim_weight(200.0)
        self.assertAlmostEqual(self.hw.get_weight(), 200.0, delta=1.0)

        # Test Tare
        self.assertTrue(self.hw.tare())
        self.assertAlmostEqual(self.hw.get_weight(), 0.0, delta=1.0)

        # Test Overload
        self.hw.set_sim_weight(4800.0)
        self.assertTrue(self.hw.is_overloaded())

        # Reset
        self.hw.set_sim_weight(180.0)
        self.assertFalse(self.hw.is_overloaded())

        # Test photo capture
        photo_path = self.hw.capture_photo()
        self.assertTrue(Path(photo_path).exists())

    def test_embedded_api_scale_endpoints(self) -> None:
        server = start_api_server("127.0.0.1", 8098, self.db_path, self.hw)
        try:
            # 1. GET /scale/live
            with urllib.request.urlopen("http://127.0.0.1:8098/scale/live") as resp:
                self.assertEqual(resp.status, 200)
                data = json.loads(resp.read().decode())
                self.assertIn("live_weight_g", data)
                self.assertIn("battery_pct", data)

            # 2. POST /scale/tare
            req = urllib.request.Request("http://127.0.0.1:8098/scale/tare", data=b"{}", headers={"Content-Type": "application/json"})
            with urllib.request.urlopen(req) as resp:
                self.assertEqual(resp.status, 200)
                data = json.loads(resp.read().decode())
                self.assertTrue(data.get("success"))

            # 3. POST /scale/capture
            self.hw.set_sim_weight(250.0)
            req = urllib.request.Request(
                "http://127.0.0.1:8098/scale/capture",
                data=json.dumps({"hint": "medjool dates"}).encode(),
                headers={"Content-Type": "application/json"},
            )
            with urllib.request.urlopen(req) as resp:
                self.assertEqual(resp.status, 200)
                data = json.loads(resp.read().decode())
                self.assertTrue(data.get("saved_to_history"))
                self.assertIn("meal_id", data)
                self.assertIn("nutrients", data)
                self.assertGreater(data["nutrients"]["calories_kcal"], 0)
        finally:
            server.shutdown()
            server.server_close()


if __name__ == "__main__":
    unittest.main()
