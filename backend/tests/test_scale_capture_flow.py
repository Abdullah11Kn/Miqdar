from __future__ import annotations

import base64
import io
import json
import shutil
import tempfile
import unittest
import urllib.error
import urllib.request
from pathlib import Path
from unittest.mock import MagicMock, patch

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
        self.hw.analyze_on_scale = True
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
        hw.analyze_on_scale = True
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

    def test_real_scale_refuses_a_weight_that_never_settles(self) -> None:
        module = FakeHardwareModule(grams=170.0)
        module.get_stable_weight = lambda *_args, **_kwargs: None
        hw = self.real_scale(module)
        status, body = self.request(self.serve(hw), "/scale/capture", {})
        self.assertEqual(status, 422)
        self.assertEqual(body["error"], "WEIGHT_NOT_STEADY")
        self.assertEqual(hw.latest_capture_event["status"], "error")

    def test_a_short_wobble_still_settles_but_constant_movement_does_not(self) -> None:
        with patch.dict("sys.modules", {"lgpio": MagicMock()}):
            import hardware

        wobble = [170.0] * 18 + [176.0, 164.0]
        with patch.object(hardware, "_recent", return_value=wobble):
            self.assertAlmostEqual(hardware._wait_stable(1.0, 1.0, 1.0), 170.0)
        moving = [150.0 + i for i in range(20)]
        with patch.object(hardware, "_recent", return_value=moving):
            self.assertIsNone(hardware._wait_stable(1.0, 1.0, 0.3))

    def plate_call(self, server, action, grams=None):
        if grams is not None:
            self.request(server, "/scale/simulate", {"weight_g": grams})
        return self.request(server, f"/scale/plate/{action}", {})

    def test_mixed_plate_gets_each_foods_grams_from_the_change_in_weight(self) -> None:
        self.hw.analyze_on_scale = False
        server = self.serve(self.hw)
        self.assertEqual(self.plate_call(server, "add", 200.0)[0], 200)
        self.plate_call(server, "add", 320.0)
        status, body = self.plate_call(server, "finish", 365.0)
        self.assertEqual(status, 200)
        plate = body["plate"]
        self.assertEqual(plate["state"], "finished")
        for step, grams in zip(plate["steps"], [200.0, 120.0, 45.0], strict=True):
            self.assertAlmostEqual(step["grams"], grams, delta=1.0)  # the simulated scale has noise

        status, photo = self.request(server, "/scale/plate/photo?step=1")
        self.assertEqual(status, 200)
        self.assertTrue(photo["image_base64"])
        self.assertEqual(self.request(server, "/scale/plate/photo?step=9")[0], 404)
        self.assertNotIn("image_base64", json.dumps(self.hw.status()))

        self.plate_call(server, "cancel")
        self.assertIsNone(self.hw.status()["plate"])

    def test_each_plate_step_has_its_own_id_even_at_the_same_reading(self) -> None:
        server = self.serve(self.hw)
        _, first = self.plate_call(server, "add", 200.0)
        self.plate_call(server, "undo")
        _, second = self.plate_call(server, "add", 200.0)
        self.assertNotEqual(first["plate"]["steps"][0]["step_id"], second["plate"]["steps"][0]["step_id"])

    def test_a_restart_changes_the_boot_id(self) -> None:
        other = ScaleHardwareAdapter(force_mock=True)
        self.assertNotEqual(self.hw.status()["boot_id"], other.status()["boot_id"])

    def test_plate_photo_refuses_a_step_that_is_not_a_number(self) -> None:
        server = self.serve(self.hw)
        self.plate_call(server, "add", 200.0)
        for step in ("abc", "-1"):
            self.assertEqual(self.request(server, f"/scale/plate/photo?step={step}")[0], 404)

    def test_finish_with_no_new_food_closes_the_plate_without_an_extra_step(self) -> None:
        server = self.serve(self.hw)
        self.plate_call(server, "add", 200.0)
        self.plate_call(server, "add", 320.0)
        _, body = self.plate_call(server, "finish")
        self.assertEqual(len(body["plate"]["steps"]), 2)
        self.assertEqual(body["plate"]["state"], "finished")

    def test_undo_removes_the_last_food_and_the_next_grams_follow_from_the_one_before(self) -> None:
        server = self.serve(self.hw)
        self.plate_call(server, "add", 200.0)
        self.plate_call(server, "add", 320.0)
        _, body = self.plate_call(server, "undo")
        self.assertEqual(len(body["plate"]["steps"]), 1)
        _, body = self.plate_call(server, "add", 290.0)
        self.assertAlmostEqual(body["plate"]["steps"][1]["grams"], 90.0, delta=1.0)
        self.plate_call(server, "undo")
        _, body = self.plate_call(server, "undo")
        self.assertIsNone(body["plate"])

    def test_plate_refuses_a_small_addition_a_lower_weight_and_an_empty_plate(self) -> None:
        server = self.serve(self.hw)
        status, body = self.plate_call(server, "add", 0.0)
        self.assertEqual((status, body["error"]), (422, "EMPTY_SCALE"))
        self.plate_call(server, "add", 200.0)
        status, body = self.plate_call(server, "add", 203.0)
        self.assertEqual((status, body["error"]), (422, "PLATE_STEP_TOO_SMALL"))
        status, body = self.plate_call(server, "add", 150.0)
        self.assertEqual((status, body["error"]), (422, "PLATE_WEIGHT_DROPPED"))
        self.assertEqual(len(self.hw.plate["steps"]), 1)

    def test_real_scale_plate_refuses_a_weight_that_never_settles(self) -> None:
        module = FakeHardwareModule(grams=170.0)
        module.get_stable_weight = lambda *_args, **_kwargs: None
        status, body = self.plate_call(self.serve(self.real_scale(module)), "add")
        self.assertEqual((status, body["error"]), (422, "WEIGHT_NOT_STEADY"))

    def test_zero_capture_and_auto_capture_wait_while_a_plate_is_open(self) -> None:
        server = self.serve(self.hw)
        self.plate_call(server, "add", 200.0)
        self.assertEqual(self.request(server, "/scale/tare", {})[1]["error"], "PLATE_OPEN")
        self.assertEqual(self.request(server, "/scale/capture", {})[1]["error"], "PLATE_OPEN")
        self.assertFalse(scale_app.AutoCaptureMonitor(self.hw, lambda: self.fail("captured")).step())
        self.plate_call(server, "cancel")
        self.assertEqual(self.request(server, "/scale/tare", {})[0], 200)

    def test_a_finished_plate_waits_for_the_phone_and_blocks_a_new_one(self) -> None:
        server = self.serve(self.hw)
        self.plate_call(server, "finish", 200.0)
        status, body = self.plate_call(server, "add", 300.0)
        self.assertEqual((status, body["error"]), (409, "PLATE_OPEN"))
        self.assertEqual(self.request(server, "/scale/capture", {})[0], 200)

    def test_touchscreen_shows_the_plate_buttons(self) -> None:
        class Painter:
            def rect(self, *_):
                pass

            def text(self, *_):
                pass

        plate = {"steps": [{"grams": 120.0}]}
        actions = [b[4] for b in scale_app.draw_screen(Painter(), {"screen": "weigh", "plate": plate})]
        for action in ("plate_undo", "plate_add", "plate_finish", "plate_cancel"):
            self.assertIn(action, actions)
        self.assertNotIn("zero", actions)
        idle = [b[4] for b in scale_app.draw_screen(Painter(), {"screen": "weigh"})]
        self.assertIn("plate_add", idle)
        self.assertIn("capture", idle)

    def test_photo_for_the_app_is_downscaled(self) -> None:
        hw = self.real_scale(FakeHardwareModule(grams=240.0))
        hw.analyze_on_scale = False
        big = io.BytesIO()
        scale_app.Image.new("RGB", (2304, 1296), (200, 80, 40)).save(big, "JPEG")
        with scale_app.Image.open(io.BytesIO(base64.b64decode(hw._encode_photo(big.getvalue())))) as sent:
            self.assertEqual(sent.size, (1280, 720))

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

    def test_default_scale_sends_the_photo_and_needs_no_ai_key(self) -> None:
        hw = self.real_scale(FakeHardwareModule(grams=240.0))
        hw.analyze_on_scale = False
        server = self.serve(hw)
        with patch.object(scale_app, "analyze_and_save") as analysis, \
                patch.dict("os.environ", {"GEMINI_API_KEY": "", "MIQDAR_RECOGNITION_PROVIDER": ""}):
            status, body = self.request(server, "/scale/capture", {})
            _, health = self.request(server, "/health")
        analysis.assert_not_called()
        self.assertEqual(status, 200)
        self.assertEqual(body["status"], "photo")
        self.assertEqual(body["weight_g"], 240.0)
        self.assertTrue(body["image_base64"])
        self.assertEqual(health["recognition"]["provider"], "gemini-in-app")
        self.assertEqual(self.request(server, "/scale/capture/latest")[1]["status"], "photo")

    def test_phone_result_reaches_the_scale_only_for_the_current_capture(self) -> None:
        hw = self.real_scale(FakeHardwareModule(grams=240.0))
        hw.analyze_on_scale = False
        server = self.serve(hw)
        event_id = self.request(server, "/scale/capture", {})[1]["event_id"]
        stale = {"event_id": "cap-old", "food": {"name_en": "Old"}, "nutrients": {}}
        self.assertFalse(self.request(server, "/scale/capture/result", stale)[1]["accepted"])
        self.assertIsNone(hw.latest_analysis)
        current = {"event_id": event_id, "food": {"name_en": "Jareesh"}, "nutrients": {"calories_kcal": 300}}
        self.assertTrue(self.request(server, "/scale/capture/result", current)[1]["accepted"])
        self.assertEqual(hw.latest_analysis["food"]["name_en"], "Jareesh")
        self.assertEqual(hw.latest_analysis["weight_g"], 240.0)

    def test_simulate_route_does_not_exist_on_a_real_scale(self) -> None:
        hw = self.real_scale(FakeHardwareModule())
        self.assertEqual(self.request(self.serve(hw), "/scale/simulate", {"weight_g": 100})[0], 404)


if __name__ == "__main__":
    unittest.main()
