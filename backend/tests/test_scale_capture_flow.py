from __future__ import annotations

import json
import shutil
import tempfile
import unittest
import urllib.error
import urllib.request
from pathlib import Path
from unittest.mock import patch

import app as scale_app
from app import (
    AutoCaptureMonitor, CameraUnavailableError, ScaleHardwareAdapter, perform_capture, start_api_server,
)

ROOT = Path(__file__).resolve().parents[2]
SOURCE_DB = ROOT / "database" / "miqdar_nutrition.db"
SAMPLE = ROOT / "evaluation" / "sample_images" / "kabsa.jpg"


class FakeHardwareModule:
    """Stands in for hardware.py: a working load cell, with or without a working camera."""

    def __init__(self, grams: float = 180.0, camera_ok: bool = True) -> None:
        self.grams = grams
        self.camera_ok = camera_ok
        self.released = False

    def start(self, zero=True, camera=True): pass
    def stop(self): pass
    def get_weight(self): return self.grams
    def get_stable_weight(self, *_args, **_kwargs): return self.grams
    def is_overloaded(self): return False
    def is_stable(self, window_s=1.0): return True
    def tare(self, timeout_s=5.0): return True
    def release_camera(self): self.released = True

    def capture_photo(self, path):
        if not self.camera_ok:
            raise RuntimeError("camera cable unplugged")
        Path(path).write_bytes(SAMPLE.read_bytes())
        return str(path)


class ScaleCaptureFlowTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp_dir = Path(tempfile.mkdtemp(prefix="scale-flow-"))
        self.db_path = self.temp_dir / "test.db"
        shutil.copy2(SOURCE_DB, self.db_path)
        self._env = patch.dict("os.environ", {"MIQDAR_RECOGNITION_PROVIDER": "mock", "MIQDAR_QUIET": "1"})
        self._env.start()
        self._no_cli_camera = patch.object(scale_app.shutil, "which", return_value=None)
        self._no_cli_camera.start()
        self.hw = ScaleHardwareAdapter(force_mock=True)
        self.hw.start()

    def tearDown(self) -> None:
        self.hw.stop()
        self._no_cli_camera.stop()
        self._env.stop()
        shutil.rmtree(self.temp_dir)

    def real_scale(self, module: FakeHardwareModule) -> ScaleHardwareAdapter:
        hw = ScaleHardwareAdapter(force_mock=True)
        hw.is_mock = False
        hw._hw_module = module
        return hw

    def request(self, server, path, payload=None, headers=None):
        url = f"http://127.0.0.1:{server.server_address[1]}{path}"
        data = None if payload is None else json.dumps(payload).encode()
        req = urllib.request.Request(url, data=data, headers=headers or {})
        try:
            with urllib.request.urlopen(req) as resp:
                return resp.status, json.loads(resp.read().decode())
        except urllib.error.HTTPError as exc:
            return exc.code, json.loads(exc.read().decode())

    def serve(self, hw):
        server = start_api_server("127.0.0.1", 0, self.db_path, hw)
        self.addCleanup(server.server_close)
        self.addCleanup(server.shutdown)
        return server

    def test_calories_scale_with_the_measured_weight_not_a_default(self) -> None:
        self.hw.place_sim_food(100.0)
        at_100 = perform_capture(self.hw, self.db_path, source="phone", hint="white rice")
        self.hw.place_sim_food(250.0)
        at_250 = perform_capture(self.hw, self.db_path, source="phone", hint="white rice")
        self.assertAlmostEqual(at_250["weight_g"], 250.0, delta=1.0)
        self.assertAlmostEqual(
            at_250["nutrients"]["calories_kcal"], at_100["nutrients"]["calories_kcal"] * 2.5, delta=3.0
        )

    def test_real_scale_with_dead_camera_fails_instead_of_using_a_stock_photo(self) -> None:
        module = FakeHardwareModule(camera_ok=False)
        hw = self.real_scale(module)
        with self.assertRaises(CameraUnavailableError):
            hw.capture_photo(self.temp_dir / "x.jpg")
        self.assertFalse((self.temp_dir / "x.jpg").exists())
        self.assertTrue(module.released)

        status, body = self.request(self.serve(hw), "/scale/capture", {})
        self.assertEqual(status, 503)
        self.assertEqual(body["error"], "CAMERA_UNAVAILABLE")
        self.assertEqual(hw.latest_capture_event["status"], "error")

    def test_real_scale_refuses_an_empty_plate(self) -> None:
        hw = self.real_scale(FakeHardwareModule(grams=0.4))
        status, body = self.request(self.serve(hw), "/scale/capture", {})
        self.assertEqual(status, 422)
        self.assertEqual(body["error"], "EMPTY_SCALE")

    def test_pi_without_hardware_stops_instead_of_simulating(self) -> None:
        with patch.object(scale_app, "_on_raspberry_pi", return_value=True), \
                patch.dict("sys.modules", {"hardware": None}):
            with self.assertRaises(SystemExit) as caught:
                ScaleHardwareAdapter()
        self.assertIn("install_pi_desktop.sh", str(caught.exception))

    def test_live_poll_stays_small_and_the_photo_comes_from_latest(self) -> None:
        server = self.serve(self.hw)
        self.hw.place_sim_food(200.0, "jareesh")
        status, captured = self.request(server, "/scale/capture", {"save": False, "hint": "white rice"})
        self.assertEqual(status, 200)
        self.assertFalse(captured["saved_to_history"])
        self.assertTrue(captured["simulated"])
        self.assertTrue(captured["image_base64"])

        _, live = self.request(server, "/scale/live")
        self.assertEqual(live["latest_capture"]["event_id"], captured["event_id"])
        self.assertNotIn("image_base64", live["latest_capture"])
        self.assertLess(len(json.dumps(live)), 6000)

        status, latest = self.request(server, "/scale/capture/latest")
        self.assertEqual(status, 200)
        self.assertEqual(latest["event_id"], captured["event_id"])
        self.assertTrue(latest["image_base64"])
        self.assertAlmostEqual(latest["nutrients"]["calories_kcal"], captured["nutrients"]["calories_kcal"])

    def test_auto_capture_fires_once_per_placement(self) -> None:
        calls = []

        def capture():
            calls.append(self.hw.get_weight())
            self.hw.last_capture_weight_g = self.hw.get_weight()

        monitor = AutoCaptureMonitor(self.hw, capture)
        self.hw.is_stable = lambda window_s=1.0: True

        self.assertFalse(monitor.step())             # empty plate
        self.hw.place_sim_food(300.0)
        self.assertTrue(monitor.step())              # food settled
        self.assertFalse(monitor.step())             # still resting: no second photo
        self.assertEqual(len(calls), 1)

        self.hw.place_sim_food(360.0)                # more food added
        self.assertTrue(monitor.step())
        self.hw.place_sim_food(0.0)                  # plate cleared
        self.assertFalse(monitor.step())
        self.hw.place_sim_food(300.0)                # same weight again is a new meal
        self.assertTrue(monitor.step())
        self.assertEqual(len(calls), 3)

    def test_auto_capture_waits_for_the_weight_to_settle(self) -> None:
        calls = []
        monitor = AutoCaptureMonitor(self.hw, lambda: calls.append(1))
        self.hw.place_sim_food(300.0)                # just placed: hand may still be in frame
        self.assertFalse(monitor.step())
        self.assertEqual(calls, [])

    def test_auto_capture_of_an_empty_plate_does_not_interrupt_the_user(self) -> None:
        self.hw.place_sim_food(300.0)
        with patch.object(scale_app, "analyze_and_save", side_effect=scale_app.RecognitionError("no food")) as call:
            call.side_effect.code = "NOT_FOOD"
            with self.assertRaises(scale_app.RecognitionError):
                perform_capture(self.hw, self.db_path, source="auto")
        self.assertIsNone(self.hw.latest_capture_event)
        self.assertEqual(self.hw.capture_state, "idle")

    def test_touchscreen_reads_the_real_nutrient_keys(self) -> None:
        gui = scale_app.ScaleTouchscreenApp.__new__(scale_app.ScaleTouchscreenApp)
        gui.state = {}
        gui.hw = self.hw
        gui._redraw = lambda: None
        gui._show_results({"food": {"name_en": "Rice"}, "nutrients": {
            "calories_kcal": 325.0, "carbohydrate_g": 70.0, "protein_g": 6.0, "fat_g": 1.0, "sugar_g": 0.2,
        }}, 250.0)
        self.assertEqual((gui.state["kcal"], gui.state["carbs"], gui.state["protein"]), (325.0, 70.0, 6.0))

    def test_token_protects_camera_and_photo_but_not_the_live_weight(self) -> None:
        server = self.serve(self.hw)
        with patch.dict("os.environ", {"MIQDAR_API_TOKEN": "secret"}):
            self.assertEqual(self.request(server, "/scale/capture", {})[0], 401)
            self.assertEqual(self.request(server, "/scale/capture/latest")[0], 401)
            self.assertEqual(self.request(server, "/scale/live")[0], 200)
            ok = {"Authorization": "Bearer secret"}
            self.assertEqual(self.request(server, "/scale/tare", {}, ok)[0], 200)

    def test_simulate_route_does_not_exist_on_a_real_scale(self) -> None:
        hw = self.real_scale(FakeHardwareModule())
        self.assertEqual(self.request(self.serve(hw), "/scale/simulate", {"weight_g": 100})[0], 404)


if __name__ == "__main__":
    unittest.main()
