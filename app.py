#!/usr/bin/env python3
"""Miqdar - Unified Smart Food Scale & API Application.

Senior Project: Smart Nutrition Scale & Mobile System
Integration: Electrical Engineering (EE) Hardware + Software (SWE/ICS) Full-Stack + Flutter Mobile App

Features:
  1. 3.5" Touchscreen GUI (640x480) for the Waveshare DSI LCD (E): English, large text, two big buttons.
  2. Hardware driver integration with EE handover (hardware.py + scale.py):
     - hw.start(), hw.get_weight(), hw.get_stable_weight(), hw.tare(), hw.capture_photo(), hw.is_overloaded(), hw.stop()
     - Automatic mock fallback on macOS / non-Pi systems (with realistic weight simulation & sample images).
  3. Food Recognition & Nutrition Calculation:
     - Powered by Google Gemini Vision (gemini-3.1-flash-lite / gemini-3.8-flash) & Miqdar SQLite database.
     - Accurate macronutrient scaling: calories, protein, carbs, fat, sugar, sodium, potassium.
     - Clinical alerts evaluation (hypertension, diabetes thresholds).
  4. Embedded REST API Server (runs concurrently in background on port 8080):
     - Serves Flutter mobile app: /health, /recognize, /meals, /history, /goals, /health-profile, /recommendations
     - Live scale telemetry endpoints: /scale/live, /scale/tare, /scale/capture
  5. Automatic Sync: Meals captured on the physical scale are saved to database and immediately appear in the mobile diary.
  6. Service Installer: 'python3 app.py --install-service' configures auto-start on Raspberry Pi boot.

Usage:
  python3 app.py                 # Runs Touchscreen GUI + Background API server + Hardware
  python3 app.py --windowed      # 640x480 window (recommended for Mac/PC testing)
  python3 app.py --fullscreen    # Fullscreen mode (for 3.5" Pi LCD)
  python3 app.py --headless      # Runs API server and scale monitor without GUI
  python3 app.py --mock          # Force simulated scale & camera mode
  python3 app.py --self-test     # Runs EE hardware verification routine
  python3 app.py --install-service # Configures systemd auto-start on Raspberry Pi
  python3 app.py --auto-capture    # Also capture by itself when food settles (default: only when CAPTURE is pressed)
  python3 app.py --analyze-on-scale # Recognise here against the database (default: the phone app calls Gemini)

Split setup (Pi = scale, laptop = recognition + database):
  laptop:  python3 app.py --headless --mock                      # backend server on port 8080
  Pi:      python3 app.py --fullscreen --server http://192.168.137.1:8080
  With --server (or MIQDAR_SERVER), the Pi sends the photo + weight to the laptop's
  /recognize and saves the meal with /meals. backend/, database/ and .env stay on the laptop.
"""
from __future__ import annotations

import argparse
import base64
import hmac
import io
import json
import os
import random
import socket
import sqlite3
import sys
import threading
import time
import urllib.error
import shutil
import subprocess
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any, Callable, Dict, List, Optional, Tuple
from urllib.parse import parse_qs, urlparse

# Ensure project root & backend are in python path
ROOT = Path(__file__).resolve().parent
if (ROOT / "backend").is_dir():
    sys.path.insert(0, str(ROOT / "backend"))
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

# Load environment variables (.env)
for env_candidate in [
    ROOT / "backend" / ".env",
    ROOT / ".env",
    Path.home() / ".miqdar_env",
]:
    if env_candidate.exists():
        with env_candidate.open(encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    k, v = line.split("=", 1)
                    os.environ.setdefault(k.strip(), v.strip().strip('"').strip("'"))

# Set working defaults for Gemini model configuration
os.environ.setdefault("GEMINI_MODEL", "gemini-3.1-flash-lite-preview")
os.environ.setdefault("GEMINI_FALLBACK_MODELS", "gemini-3-flash-preview,gemini-flash-latest")
if os.environ.get("GEMINI_API_KEY"):
    os.environ.setdefault("MIQDAR_RECOGNITION_PROVIDER", "gemini")

# Import optional imaging libraries
try:
    from PIL import Image, ImageDraw, ImageFont
    HAS_PIL = True
except ImportError:
    HAS_PIL = False

# Import backend modules if present
try:
    from miqdar_backend.alert_engine import evaluate_alerts
    from miqdar_backend.database import (
        alerts, connect as db_connect, find_food_for_label, food_search,
        goals_for_user, health_profile_for_user, history, save_meal,
        scaled_nutrients, update_goals, update_health_profile,
    )
    from miqdar_backend.recognition import configured_provider
    from miqdar_backend.recommendations import normalise_profile, recommend_meals
    from miqdar_backend.service import (
        RecognitionError, decode_image, recognize_food,
    )
    HAS_BACKEND = True
except ImportError:
    HAS_BACKEND = False

    class RecognitionError(Exception):          # placeholder so error handling works without backend/
        code = "RECOGNITION_FAILED"
        http_status = 502

        def __init__(self, message: str, *, candidates: Optional[list] = None) -> None:
            super().__init__(message)
            self.candidates = candidates or []

        def to_dict(self) -> dict:
            return {"error": self.code, "message": str(self), "candidates": []}


class CameraUnavailableError(RecognitionError):
    code = "CAMERA_UNAVAILABLE"
    http_status = 503


class EmptyScaleError(RecognitionError):
    code = "EMPTY_SCALE"
    http_status = 422


class UnsteadyScaleError(RecognitionError):
    code = "WEIGHT_NOT_STEADY"
    http_status = 422


class CaptureBusyError(RecognitionError):
    code = "CAPTURE_IN_PROGRESS"
    http_status = 409


class CaptureFailedError(RecognitionError):
    code = "CAPTURE_FAILED"
    http_status = 500


class RemoteRecognitionError(RecognitionError):
    """A classified failure reported by the --server recognition host."""

    def __init__(self, code: str, message: str, http_status: int) -> None:
        super().__init__(message)
        self.code = code
        self.http_status = http_status


# Default database and configuration
DEFAULT_DB = ROOT / "database" / "miqdar_nutrition.db"
PHOTOS_DIR = ROOT / "photos"
DEMO_USER = "demo-user"
MIN_CAPTURE_WEIGHT_G = 5.0     # below this a reading is sensor noise, not food
SIM_SAMPLES = {
    "kabsa": "kabsa.jpg", "shawarma": "shawarma.jpeg", "jareesh": "jareesh.jpeg",
    "pizza": "pizza.jpeg", "burger": "burger.jpg",
}


def _on_raspberry_pi() -> bool:
    try:
        return "Raspberry Pi" in Path("/proc/device-tree/model").read_text(errors="ignore")
    except OSError:
        return False


# ==============================================================================
# 1. HARDWARE ADAPTER LAYER (Real EE hardware.py with Mock Fallback)
# ==============================================================================
class ScaleHardwareAdapter:
    """Unified Hardware Adapter for the Miqdar Smart Scale.
    
    Interacts with the real EE handover driver (hardware.py + scale.py) on Raspberry Pi OS.
    Automatically degrades to an interactive software simulation when running on macOS/Windows
    or when physical sensors are disconnected.
    """

    def __init__(self, force_mock: bool = False) -> None:
        self.force_mock = force_mock
        self.is_mock = True
        self.running = False
        self._hw_module = None
        self._lock = threading.Lock()

        # Simulated state
        self._sim_weight = 0.0
        self._sim_tare = 0.0
        self._sim_stable = True
        self._sim_thread: Optional[threading.Thread] = None
        self._sim_sample = "kabsa"
        self._sim_changed_at = 0.0

        # Two-way sync state for mobile app & physical scale
        self.latest_capture_event: Optional[Dict[str, Any]] = None
        self._event_counter = 0
        self.capture_lock = threading.Lock()
        self.capture_state = "idle"            # idle -> settling -> capturing -> analyzing
        self.last_capture_weight_g: Optional[float] = None
        self.auto_capture = False
        self.sensor_error: Optional[str] = None
        # False: the scale only weighs and photographs; the phone app calls Gemini.
        self.analyze_on_scale = False
        self.latest_analysis: Optional[Dict[str, Any]] = None

        PHOTOS_DIR.mkdir(exist_ok=True)
        self._detect_hardware()

    def _detect_hardware(self) -> None:
        if self.force_mock:
            print("[Hardware] Force mock mode requested via CLI flag.")
            self.is_mock = True
            return

        try:
            # Check if hardware.py and dependencies (lgpio, picamera2) are usable
            import hardware as real_hw
            self._hw_module = real_hw
            self.is_mock = False
            print("[Hardware] Real Raspberry Pi hardware driver detected (hardware.py).")
        except (ImportError, RuntimeError, OSError) as exc:
            self._hardware_unavailable(exc)

    def _hardware_unavailable(self, exc: Exception) -> None:
        """Fake weights and photos would give fake calories, so a Pi never simulates unless asked."""
        if _on_raspberry_pi():
            raise SystemExit(
                f"[Hardware] The scale hardware could not start: {exc}\n"
                "  Fix: run ./install_pi_desktop.sh (installs lgpio + picamera2 and a virtualenv that\n"
                "  can see them), and python3 scale.py calibrate if calibration is missing.\n"
                "  To demo without hardware on purpose: python3 app.py --mock"
            )
        self.is_mock = True
        print(f"[Hardware] Real hardware not available ({exc}). Falling back to Simulation Mode.")

    def start(self, zero: bool = True, camera: bool = True) -> None:
        with self._lock:
            if self.running:
                return
            self.running = True

            if not self.is_mock and self._hw_module:
                try:
                    self._hw_module.start(zero=zero, camera=camera)
                    print("[Hardware] Real scale & camera initialized.")
                    return
                except Exception as exc:
                    self.running = False
                    self._hardware_unavailable(exc)

            # Start simulated hardware ticker
            self._sim_weight = 0.0
            self._sim_tare = 0.0
            self._sim_stable = True
            self._sim_thread = threading.Thread(target=self._sim_loop, daemon=True)
            self._sim_thread.start()
            print("[Hardware] Simulated load-cell and camera background thread active.")

    def _sim_loop(self) -> None:
        while self.running:
            # Subtle natural noise (+/- 0.05g)
            noise = (random.random() - 0.5) * 0.1
            with self._lock:
                if abs(self._sim_weight) > 0.1:
                    self._sim_weight += noise
            time.sleep(0.1)

    def stop(self) -> None:
        with self._lock:
            self.running = False
            if not self.is_mock and self._hw_module:
                try:
                    self._hw_module.stop()
                except Exception:
                    pass

    def get_weight(self) -> float:
        """Returns live net weight in grams."""
        if not self.is_mock and self._hw_module:
            try:
                weight = float(self._hw_module.get_weight())
                self.sensor_error = None
                return weight
            except Exception as exc:
                self.sensor_error = str(exc)
                return 0.0
        with self._lock:
            net = self._sim_weight - self._sim_tare
            return round(max(0.0, net), 1)

    def get_stable_weight(self, tolerance_g: float = 1.0, window_s: float = 1.0, timeout_s: float = 5.0) -> Optional[float]:
        """Waits until the reading is steady within tolerance."""
        if not self.is_mock and self._hw_module:
            try:
                return self._hw_module.get_stable_weight(tolerance_g, window_s, timeout_s)
            except Exception:
                pass
        # In simulation: brief 0.5s pause to emulate stabilization
        time.sleep(0.5)
        return self.get_weight()

    def is_stable(self, window_s: float = 1.0) -> bool:
        """Non-blocking: has the load stayed steady for the last window_s seconds?"""
        if not self.is_mock and self._hw_module:
            try:
                return bool(self._hw_module.is_stable(window_s=window_s))
            except Exception:
                return False
        with self._lock:
            return time.monotonic() - self._sim_changed_at >= window_s

    def tare(self, timeout_s: float = 5.0) -> bool:
        """Zero button: the current load becomes 0 g."""
        if not self.is_mock and self._hw_module:
            try:
                return bool(self._hw_module.tare(timeout_s))
            except Exception:
                return False
        with self._lock:
            self._sim_tare = self._sim_weight
            self._sim_changed_at = time.monotonic()
            return True

    def is_overloaded(self) -> bool:
        """True when total gross load on the sensor exceeds 4.5 kg."""
        if not self.is_mock and self._hw_module:
            try:
                return bool(self._hw_module.is_overloaded())
            except Exception:
                return False
        with self._lock:
            return self._sim_weight > 4500.0

    def capture_photo(self, path: Optional[Path] = None) -> str:
        """Captures dish photo with multi-level hardware fallback. Returns filesystem path (str)."""
        target_path = path or (PHOTOS_DIR / time.strftime("meal_%Y%m%d_%H%M%S.jpg"))
        target_path.parent.mkdir(parents=True, exist_ok=True)

        if self.is_mock:
            return self._simulated_photo(target_path)

        # 1. Try real hardware python module if available
        if not self.is_mock and self._hw_module:
            try:
                p = self._hw_module.capture_photo(target_path)
                if Path(p).exists() and Path(p).stat().st_size > 1000:
                    print(f"[Hardware Camera] Captured photo via hardware module: {p}")
                    return str(p)
            except Exception as exc:
                print(f"[Hardware Camera] hardware.py capture failed ({exc}). Trying CLI camera drivers...")
                try:
                    self._hw_module.release_camera()    # the CLI tools cannot open a held camera
                except Exception:
                    pass

        # 2. Try rpicam-still (Raspberry Pi OS Bookworm official Camera Module 3 driver)
        rpicam_bin = shutil.which("rpicam-still") or shutil.which("/usr/bin/rpicam-still")
        if rpicam_bin:
            try:
                cmd = [
                    rpicam_bin, "-t", "800", "-o", str(target_path),
                    "--width", "1920", "--height", "1080", "-n",
                    "--autofocus-mode", "auto"
                ]
                subprocess.run(cmd, check=True, timeout=8, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
                if target_path.exists() and target_path.stat().st_size > 1000:
                    print(f"[Hardware Camera] Captured real photo via rpicam-still: {target_path}")
                    return str(target_path)
            except Exception as exc:
                print(f"[Hardware Camera] rpicam-still failed: {exc}")

        # 3. Try libcamera-still (Raspberry Pi OS Bullseye official Camera Module 3 driver)
        libcam_bin = shutil.which("libcamera-still") or shutil.which("/usr/bin/libcamera-still")
        if libcam_bin:
            try:
                cmd = [
                    libcam_bin, "-t", "800", "-o", str(target_path),
                    "--width", "1920", "--height", "1080", "-n",
                    "--autofocus-mode", "auto"
                ]
                subprocess.run(cmd, check=True, timeout=8, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
                if target_path.exists() and target_path.stat().st_size > 1000:
                    print(f"[Hardware Camera] Captured real photo via libcamera-still: {target_path}")
                    return str(target_path)
            except Exception as exc:
                print(f"[Hardware Camera] libcamera-still failed: {exc}")

        # 4. Try OpenCV (USB camera or /dev/video0)
        try:
            import cv2  # type: ignore[import-not-found]
            cap = cv2.VideoCapture(0)
            if cap.isOpened():
                for _ in range(5):  # warm up auto-exposure
                    cap.read()
                ret, frame = cap.read()
                cap.release()
                if ret and frame is not None:
                    cv2.imwrite(str(target_path), frame)
                    print(f"[Hardware Camera] Captured real photo via OpenCV /dev/video0: {target_path}")
                    return str(target_path)
        except Exception:
            pass

        # A stock photo here would produce calories for food that is not on the plate.
        raise CameraUnavailableError(
            "The scale camera did not respond. Check the camera ribbon cable, then run: rpicam-still -o test.jpg"
        )

    def _simulated_photo(self, target_path: Path) -> str:
        """Simulation mode only: a labelled sample dish stands in for the camera."""
        sample = ROOT / "evaluation" / "sample_images" / SIM_SAMPLES.get(self._sim_sample, "kabsa.jpg")
        print(f"[Hardware Camera] SIMULATED: using sample dish {sample.name}")
        if sample.exists():
            target_path.write_bytes(sample.read_bytes())
        elif HAS_PIL:
            Image.new("RGB", (640, 480), color=(180, 100, 40)).save(target_path, "JPEG")
        else:
            raise CameraUnavailableError("Simulation mode has no sample photo available")
        return str(target_path)

    def set_sim_weight(self, grams: float) -> None:
        """Development helper to set simulated plate weight."""
        with self._lock:
            self._sim_weight = max(0.0, float(grams))
            self._sim_changed_at = time.monotonic()

    def place_sim_food(self, grams: float, sample: Optional[str] = None) -> None:
        """Simulation mode: puts food on a freshly zeroed plate."""
        with self._lock:
            self._sim_tare = 0.0
            if sample in SIM_SAMPLES:
                self._sim_sample = sample
        self.set_sim_weight(grams)

    @staticmethod
    def _encode_photo(img_bytes: bytes) -> Optional[str]:
        if not img_bytes:
            return None
        try:
            if HAS_PIL:
                im = Image.open(io.BytesIO(img_bytes))
                im.thumbnail((1280, 960))
                buf = io.BytesIO()
                im.convert("RGB").save(buf, format="JPEG", quality=80)
                img_bytes = buf.getvalue()
        except Exception as e:
            print(f"[Capture] Thumbnail error ({e}), sending full photo bytes.")
        return base64.b64encode(img_bytes).decode("ascii")

    def _publish_event(self, fields: Dict[str, Any], img_bytes: bytes, grams: float, source: str) -> Dict[str, Any]:
        image = self._encode_photo(img_bytes)
        with self._lock:
            self._event_counter += 1
            event = {
                "event_id": f"cap-{self._event_counter}-{int(time.time())}",
                "timestamp": time.time(),
                "source": source,
                "simulated": self.is_mock,
                "weight_g": float(grams),
                "image_base64": image,
                **fields,
            }
            self.latest_capture_event = event
        return event

    def record_capture_event(self, result: Dict[str, Any], img_bytes: bytes, grams: float, source: str = "scale") -> Dict[str, Any]:
        """Stores the latest capture event for real-time mobile app and scale synchronization."""
        return self._publish_event({
            "status": "ok",
            "food": result.get("food", {}),
            "nutrients": result.get("nutrients", {}),
            "candidates": result.get("candidates", []),
            "alerts": result.get("alerts", []),
            "timing": result.get("timing", {}),
            "confidence": result.get("confidence", 1.0),
            "recognition_provider": result.get("recognition_provider"),
            "recognition_model": result.get("recognition_model"),
            "recognition_cached": result.get("recognition_cached", False),
            "meal_id": result.get("meal_id"),
            "saved_to_history": bool(result.get("saved_to_history")),
        }, img_bytes, grams, source)

    def record_photo_event(self, img_bytes: bytes, grams: float, source: str = "scale") -> Dict[str, Any]:
        """Publishes a weighed photo for the phone app to analyse."""
        return self._publish_event({"status": "photo"}, img_bytes, grams, source)

    def record_analysis(self, payload: Dict[str, Any]) -> bool:
        """Stores the phone's result so the touchscreen can show it too. False if out of date."""
        latest = self.latest_capture_event
        if not latest or latest["event_id"] != payload.get("event_id"):
            return False
        self.latest_analysis = {
            "event_id": latest["event_id"],
            "food": payload.get("food", {}),
            "nutrients": payload.get("nutrients", {}),
            "weight_g": latest["weight_g"],
        }
        return True

    def record_capture_error(self, exc: RecognitionError, img_bytes: bytes, grams: float, source: str = "scale") -> Dict[str, Any]:
        """Publishes a failed capture so the app can show the photo and what went wrong."""
        return self._publish_event({"status": "error", **exc.to_dict()}, img_bytes, grams, source)

    def status(self) -> Dict[str, Any]:
        """Telemetry diagnostics. Polled twice a second, so the photo stays out of it:
        fetch it once per new event_id from GET /scale/capture/latest."""
        w = self.get_weight()
        latest = self.latest_capture_event
        summary = None
        if latest:
            summary = {k: v for k, v in latest.items() if k != "image_base64"}
            summary["age_s"] = round(time.time() - latest["timestamp"], 1)
        return {
            "mode": "real" if not self.is_mock else "simulated",
            "live_weight_g": 0.0 if abs(w) < 0.5 else w,
            "is_stable": self.is_stable(),
            "is_overloaded": self.is_overloaded(),
            "sensor_ok": self.sensor_error is None,
            "sensor_error": self.sensor_error,
            "tare_g": round(self._sim_tare, 1) if self.is_mock else 0.0,
            "capacity_g": 5000,
            "battery_pct": self._read_battery_percent(),
            "capture_state": self.capture_state,
            "auto_capture": self.auto_capture,
            "latest_capture": summary,
        }

    def _read_battery_percent(self) -> int:
        # On Raspberry Pi, throttling status 0x0 indicates good power (100%)
        # In battery operation with LM2596, default to a realistic 94%
        return 94


# ==============================================================================
# 1b. RECOGNITION: local backend (laptop) or remote server (Pi -> laptop)
# ==============================================================================
def _post_json(url: str, payload: dict, timeout: float = 60.0) -> dict:
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json"}, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        try:
            body = json.loads(exc.read().decode("utf-8"))
            msg = body.get("message") or body.get("error") or str(body)
            code = body.get("error") or "RECOGNITION_FAILED"
        except Exception:
            msg, code = str(exc), "RECOGNITION_FAILED"
        raise RemoteRecognitionError(code, f"Server error {exc.code}: {msg}", exc.code) from None
    except urllib.error.URLError as exc:
        raise RuntimeError(f"Cannot reach the recognition server at {url} ({exc.reason}). "
                           "Is the laptop server running and on the same Wi-Fi?") from None


def analyze_and_save(
    img_bytes: bytes,
    grams: float,
    db_path: Path,
    server: Optional[str] = None,
    user_id: str = DEMO_USER,
    meal_type: str = "Meal",
    hint: Optional[str] = None,
    save: bool = True,
) -> Dict[str, Any]:
    """Recognise the food and (unless save=False, a draft the phone confirms) save the meal.

    server given  -> send photo + weight to <server>/recognize, then save with <server>/meals.
    no server     -> use the local backend + database (the original single-machine mode).
    Returns the recognition result (food, nutrients, confidence, ...) plus meal_id.
    """
    if server:
        base = server.rstrip("/")
        result = _post_json(f"{base}/recognize", {
            "user_id": user_id,
            "image_base64": base64.b64encode(img_bytes).decode("ascii"),
            "weight_g": float(grams),
            "hint": hint,
        })
        if not save:
            result["saved_to_history"] = False
            return result
        saved = _post_json(f"{base}/meals", {
            "user_id": user_id,
            "food_id": result["food"]["food_id"],
            "weight_g": float(grams),
            "confidence": float(result.get("confidence", 1.0)),
            "meal_type": meal_type,
        })
        result["meal_id"] = saved.get("meal_id")
        result["saved_to_history"] = True
        return result

    if not HAS_BACKEND:
        raise RuntimeError("No recognition backend on this device. Start with "
                           "--server http://<laptop-ip>:8080 (see the header of app.py).")
    if not db_path.exists():
        raise RuntimeError("Database not found. Please run ./run_checks.sh first.")
    with db_connect(db_path) as conn:
        result = recognize_food(conn, user_id=user_id, image_bytes=img_bytes, weight_g=float(grams), hint=hint)
        if not save:
            result["saved_to_history"] = False
            return result
        meal_id = save_meal(
            conn, user_id=user_id, food_id=result["food"]["food_id"], weight_g=float(grams),
            confidence=float(result.get("confidence", 1.0)), nutrients=result["nutrients"], meal_type=meal_type,
        )
    result["meal_id"] = meal_id
    result["saved_to_history"] = True
    return result


def perform_capture(
    hw: ScaleHardwareAdapter,
    db_path: Path,
    *,
    server: Optional[str] = None,
    source: str = "phone",
    user_id: str = DEMO_USER,
    meal_type: str = "Meal",
    hint: Optional[str] = None,
    save: bool = False,
    stable_timeout_s: float = 5.0,
) -> Dict[str, Any]:
    """The one capture pipeline behind the phone, the touchscreen and auto-capture:
    settle -> photo -> recognise -> publish an event every client can pick up.

    Failures are published too (with the photo when there is one) and re-raised as
    RecognitionError. Only one capture runs at a time; camera and load cell are shared.
    """
    if not hw.capture_lock.acquire(blocking=False):
        raise CaptureBusyError("The scale is already capturing. Please wait a moment.")
    grams = 0.0
    img_bytes = b""
    try:
        hw.capture_state = "settling"
        stable = hw.get_stable_weight(timeout_s=stable_timeout_s)
        if stable is None and not hw.is_mock:
            # A hand on the food changes the reading, and calories scale with this number.
            raise UnsteadyScaleError("The weight is still moving. Take your hand off the plate, then capture again.")
        grams = stable if stable is not None and stable > 0 else hw.get_weight()
        if grams < MIN_CAPTURE_WEIGHT_G:
            if not hw.is_mock:
                raise EmptyScaleError(f"The scale reads {grams:.0f} g. Put the food on the plate, then capture.")
            grams = 250.0                       # default demo portion in simulation mode
        hw.last_capture_weight_g = float(grams)
        hw.capture_state = "capturing"
        img_bytes = Path(hw.capture_photo()).read_bytes()
        if not hw.analyze_on_scale:
            event = hw.record_photo_event(img_bytes, float(grams), source=source)
            return {
                "status": "photo",
                "event_id": event["event_id"],
                "source": source,
                "simulated": event["simulated"],
                "weight_g": float(grams),
                "image_base64": event["image_base64"],
            }
        hw.capture_state = "analyzing"
        result = analyze_and_save(
            img_bytes, float(grams), db_path, server=server, user_id=user_id,
            meal_type=meal_type, hint=hint, save=save,
        )
        event = hw.record_capture_event(result, img_bytes, float(grams), source=source)
        result["event_id"] = event["event_id"]
        result["image_base64"] = event["image_base64"]
        result["simulated"] = event["simulated"]
        return result
    except Exception as exc:
        error = exc if isinstance(exc, RecognitionError) else CaptureFailedError(str(exc))
        print(f"[Capture] {source} capture failed: {error}")
        # An empty plate settling on the scale is normal, not worth interrupting the user for.
        if not (source == "auto" and error.code in ("NOT_FOOD", "EMPTY_SCALE")):
            error.capture_event = hw.record_capture_error(error, img_bytes, float(grams), source=source)  # type: ignore[attr-defined]
        if error is exc:
            raise
        raise error from exc
    finally:
        hw.capture_state = "idle"
        hw.capture_lock.release()


class AutoCaptureMonitor:
    """Captures by itself once food has been set down and the reading has settled.

    Fires once per placement: it re-arms when the plate is cleared or the weight
    changes by REARM_DELTA_G (food added), so a resting plate never re-triggers.
    """

    MIN_WEIGHT_G = 20.0
    REARM_DELTA_G = 25.0
    SETTLE_S = 2.0
    POLL_S = 0.25

    def __init__(self, hw: ScaleHardwareAdapter, capture: Callable[[], Any]) -> None:
        self.hw = hw
        self.capture = capture

    def step(self) -> bool:
        """Runs one check. Returns True when a capture was attempted."""
        grams = self.hw.get_weight()
        if grams < self.MIN_WEIGHT_G:
            self.hw.last_capture_weight_g = None
            return False
        last = self.hw.last_capture_weight_g
        if last is not None and abs(grams - last) < self.REARM_DELTA_G:
            return False
        if self.hw.is_overloaded() or not self.hw.is_stable(window_s=self.SETTLE_S):
            return False
        try:
            self.capture()
        except CaptureBusyError:
            return False
        except Exception as exc:
            print(f"[Auto-capture] {exc}")
        return True

    def start(self) -> None:
        def loop() -> None:
            while self.hw.running:
                self.step()
                time.sleep(self.POLL_S)
        threading.Thread(target=loop, daemon=True).start()


# ==============================================================================
# 2. REST API SERVER (Embedded HTTP Server supporting Mobile App & Scale)
# ==============================================================================
class MiqdarScaleApiHandler(BaseHTTPRequestHandler):
    server_version = "MiqdarScale/1.0"

    @property
    def db_path(self) -> Path:
        return self.server.db_path  # type: ignore[attr-defined]

    @property
    def scale_hw(self) -> ScaleHardwareAdapter:
        return self.server.scale_hw  # type: ignore[attr-defined]

    def log_message(self, format: str, *args: object) -> None:
        if os.environ.get("MIQDAR_QUIET") == "1":
            return
        super().log_message(format, *args)

    def send_json(self, status: int, payload: object) -> None:
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, PUT, OPTIONS, HEAD")
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(body)

    def require_authorization(self) -> bool:
        """A tunnel makes this API public: set MIQDAR_API_TOKEN to lock the camera behind a token."""
        expected = os.environ.get("MIQDAR_API_TOKEN", "").strip()
        if not expected or hmac.compare_digest(self.headers.get("Authorization", ""), f"Bearer {expected}"):
            return True
        self.send_json(401, {"error": "unauthorized"})
        return False

    def read_json(self) -> dict:
        length = int(self.headers.get("Content-Length", "0"))
        if length > 15 * 1024 * 1024:
            raise ValueError("Request body exceeds 15 MB limit")
        payload = self.rfile.read(length) if length else b"{}"
        val = json.loads(payload)
        if not isinstance(val, dict):
            raise ValueError("JSON object required")
        return val

    def do_OPTIONS(self) -> None:
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, PUT, OPTIONS, HEAD")
        self.send_header("Content-Length", "0")
        self.end_headers()

    def do_HEAD(self) -> None:
        self.do_GET()

    def do_GET(self) -> None:
        parsed = urlparse(self.path)
        query = parse_qs(parsed.query)

        if parsed.path == "/health":
            provider_status = {"provider": "gemini-in-app", "configured": True}
            if HAS_BACKEND and self.scale_hw.analyze_on_scale:
                try:
                    p = configured_provider()
                    provider_status = {"provider": p.name, "model": getattr(p, "model", None), "configured": True}
                except Exception as e:
                    provider_status = {"provider": "error", "configured": False, "message": str(e)}
            self.send_json(200, {
                "status": "ok",
                "database": str(self.db_path.name) if self.db_path.exists() else "unseeded",
                "recognition": provider_status,
                "scale": self.scale_hw.status(),
            })
            return

        if parsed.path == "/scale/live":
            self.send_json(200, self.scale_hw.status())
            return

        if not self.require_authorization():
            return

        if parsed.path == "/scale/capture/latest":
            event = self.scale_hw.latest_capture_event
            if event:
                self.send_json(200, event)
            else:
                self.send_json(404, {"error": "NO_CAPTURE_YET"})
            return

        if not self.db_path.exists():
            self.send_json(503, {"error": "DATABASE_NOT_FOUND", "message": "Database not initialized"})
            return

        with db_connect(self.db_path) as conn:
            if parsed.path == "/foods":
                self.send_json(200, {"foods": food_search(conn, query.get("q", [""])[0])})
            elif parsed.path == "/history":
                days = int(query.get("days", ["90"])[0])
                user_id = query.get("user_id", [DEMO_USER])[0]
                self.send_json(200, {"days": days, "items": history(conn, user_id, days)})
            elif parsed.path == "/goals":
                user_id = query.get("user_id", [DEMO_USER])[0]
                self.send_json(200, goals_for_user(conn, user_id))
            elif parsed.path == "/health-profile":
                user_id = query.get("user_id", [DEMO_USER])[0]
                self.send_json(200, health_profile_for_user(conn, user_id))
            elif parsed.path == "/alerts":
                user_id = query.get("user_id", [DEMO_USER])[0]
                self.send_json(200, {"alerts": alerts(conn, user_id)})
            else:
                self.send_json(404, {"error": "route_not_found"})

    def do_POST(self) -> None:
        parsed = urlparse(self.path)
        if not self.require_authorization():
            return
        try:
            payload = self.read_json()

            # Scale Remote Tare Endpoint
            if parsed.path == "/scale/tare":
                ok = self.scale_hw.tare()
                self.send_json(200, {"success": ok, "scale": self.scale_hw.status()})
                return

            # Scale Remote Capture & Recognize Endpoint
            if parsed.path == "/scale/capture":
                result = perform_capture(
                    self.scale_hw, self.db_path,
                    server=getattr(self.server, "recognition_server", None),
                    source="phone",
                    user_id=payload.get("user_id", DEMO_USER),
                    meal_type=payload.get("meal_type", "Meal"),
                    hint=payload.get("hint"),
                    save=bool(payload.get("save", True)),
                )
                self.send_json(200, result)
                return

            if parsed.path == "/scale/capture/result":
                self.send_json(200, {"accepted": self.scale_hw.record_analysis(payload)})
                return

            # Simulation only: "put food on the plate" without hardware
            if parsed.path == "/scale/simulate":
                if not self.scale_hw.is_mock:
                    self.send_json(404, {"error": "route_not_found"})
                    return
                self.scale_hw.place_sim_food(float(payload["weight_g"]), payload.get("sample"))
                self.send_json(200, self.scale_hw.status())
                return

            if not self.db_path.exists():
                self.send_json(503, {"error": "DATABASE_NOT_FOUND"})
                return

            with db_connect(self.db_path) as conn:
                if parsed.path == "/recognize":
                    result = recognize_food(
                        conn,
                        user_id=payload.get("user_id", DEMO_USER),
                        image_bytes=decode_image(payload.get("image_base64")),
                        weight_g=float(payload["weight_g"]),
                        hint=payload.get("hint"),
                        previous_image_bytes=decode_image(payload.get("previous_image_base64")) if payload.get("previous_image_base64") else None,
                        previous_weight_g=float(payload["previous_weight_g"]) if payload.get("previous_weight_g") is not None else None,
                    )
                    self.send_json(200, result)
                elif parsed.path == "/meals":
                    user_id = str(payload.get("user_id", DEMO_USER))
                    food = find_food_for_label(conn, payload["food_id"])
                    if not food:
                        row = conn.execute(
                            "SELECT f.*, n.* FROM foods f JOIN nutrient_profiles n ON n.food_id=f.food_id WHERE f.food_id=?",
                            (payload["food_id"],),
                        ).fetchone()
                        food = dict(row) if row else None
                    if not food:
                        raise KeyError("food_id does not have a nutrition profile")
                    weight_g = float(payload["weight_g"])
                    nutrients = scaled_nutrients(food, weight_g)
                    alerts_preview, _ = evaluate_alerts(conn, user_id=user_id, nutrients=nutrients)
                    meal_id = save_meal(
                        conn, user_id=user_id, food_id=food["food_id"],
                        weight_g=weight_g, confidence=float(payload.get("confidence", 1)),
                        nutrients=nutrients, meal_type=payload.get("meal_type", "Meal"),
                    )
                    persisted, alert_ms = evaluate_alerts(
                        conn, user_id=user_id, nutrients={}, persist=True, meal_id=meal_id,
                    )
                    self.send_json(201, {
                        "meal_id": meal_id,
                        "nutrients": nutrients,
                        "alerts": alerts_preview or persisted,
                        "alert_evaluation_ms": alert_ms,
                    })
                elif parsed.path == "/recommendations":
                    user_id = str(payload.get("user_id", DEMO_USER))
                    stored = health_profile_for_user(conn, user_id)
                    supplied_profile = payload.get("profile")
                    profile = normalise_profile(
                        supplied_profile if isinstance(supplied_profile, dict) else stored
                    )
                    result = recommend_meals(
                        conn,
                        user_id=user_id,
                        profile=profile,
                        limit=int(payload.get("limit", 5)),
                    )
                    self.send_json(200, result)
                else:
                    self.send_json(404, {"error": "route_not_found"})
        except RecognitionError as exc:
            body = exc.to_dict()
            event = getattr(exc, "capture_event", None)
            if event:
                body["event_id"] = event["event_id"]
            self.send_json(exc.http_status, body)
        except KeyError as exc:
            self.send_json(400, {"error": "MISSING_FIELD", "message": f"Missing required field: {exc.args[0]}"})
        except Exception as exc:
            self.send_json(400, {"error": type(exc).__name__, "message": str(exc)})

    def do_PUT(self) -> None:
        parsed = urlparse(self.path)
        if not self.require_authorization():
            return
        try:
            payload = self.read_json()
            with db_connect(self.db_path) as conn:
                if parsed.path == "/goals":
                    user_id = str(payload.pop("user_id", DEMO_USER))
                    self.send_json(200, update_goals(conn, user_id, payload))
                elif parsed.path == "/health-profile":
                    user_id = str(payload.pop("user_id", DEMO_USER))
                    profile = normalise_profile(payload)
                    self.send_json(200, update_health_profile(conn, user_id, profile))
                else:
                    self.send_json(404, {"error": "route_not_found"})
        except Exception as exc:
            self.send_json(400, {"error": type(exc).__name__, "message": str(exc)})


def start_api_server(host: str, port: int, db_path: Path, scale_hw: ScaleHardwareAdapter,
                     recognition_server: Optional[str] = None) -> Optional[ThreadingHTTPServer]:
    try:
        server = ThreadingHTTPServer((host, port), MiqdarScaleApiHandler)
        server.db_path = db_path  # type: ignore[attr-defined]
        server.scale_hw = scale_hw  # type: ignore[attr-defined]
        server.recognition_server = recognition_server  # type: ignore[attr-defined]
        th = threading.Thread(target=server.serve_forever, daemon=True)
        th.start()
        print(f"[API Server] Starting background REST API on http://{host}:{port}")
        return server
    except OSError as exc:
        if exc.errno == 48 or "Address already in use" in str(exc):
            print(f"[API Server] Port {port} is already in use by an active server; reusing running server.")
            return None
        raise


# ==============================================================================
# 3. TOUCHSCREEN UI (640x480, 3.5" Waveshare DSI LCD): English, large text, one screen at a time
# ==============================================================================
def get_ip_address() -> str:
    """Discovers the active local IP for mobile app connection display."""
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "127.0.0.1"


C_BG = "#0A120E"
C_CARD = "#121F18"
C_TILE = "#182920"
C_LINE = "#263E31"
C_GREEN = "#059669"
C_GREEN_HI = "#10B981"
C_WHITE = "#F1F5F9"
C_MUTED = "#94A3B8"
C_RED = "#E11D48"
C_AMBER = "#D97706"
C_DISABLED = "#2A3530"
UI_FONT = "DejaVu Sans"


def _wrap(text: str, width: int) -> List[str]:
    lines, cur = [], ""
    for word in str(text).split():
        if len(cur) + len(word) + 1 > width and cur:
            lines.append(cur)
            cur = word
        else:
            cur = f"{cur} {word}".strip()
    if cur:
        lines.append(cur)
    return lines


def draw_screen(p: Any, s: Dict[str, Any]) -> List[Tuple[int, int, int, int, str]]:
    """Draws one 640x480 screen with painter p. Returns the touch buttons as (x0, y0, x1, y1, action).

    Screens: 'weigh' (live weight), 'analyzing', 'result', 'error'.
    Painter API: rect(x0, y0, x1, y1, fill), text(x, y, s, size_px, bold, fill, anchor) with anchor in
    {'center', 'w', 'e'}. The same function draws on the Tk canvas and on PIL previews.
    """
    W, H = 640, 480
    p.rect(0, 0, W, H, C_BG)
    # header
    p.text(16, 24, "MIQDAR", 22, True, C_GREEN_HI, "w")
    status, col = s.get("status", ("● READY", C_GREEN_HI))
    p.text(W - 130, 24, status, 14, True, col, "e")
    # main card
    p.rect(12, 50, W - 12, 372, C_CARD)
    screen = s.get("screen", "weigh")
    buttons: List[Tuple[int, int, int, int, str]] = []

    def button(x0: int, y0: int, x1: int, y1: int, label: str, fill: str, action: Optional[str], size: int = 30) -> None:
        p.rect(x0, y0, x1, y1, fill)
        p.text((x0 + x1) // 2, (y0 + y1) // 2, label, size, True, C_WHITE if action else C_MUTED, "center")
        if action:
            buttons.append((x0, y0, x1, y1, action))

    button(W - 115, 6, W - 12, 44, "✕ EXIT", C_RED if screen == "exit_confirm" else C_TILE, "exit", 15)

    if screen == "weigh":
        p.text(W // 2, 82, "NET WEIGHT", 18, True, C_MUTED, "center")
        grams = s.get("weight", 0.0)
        num = f"{grams:.0f}" if abs(grams) >= 0.5 else "0"
        colour = C_RED if s.get("overloaded") else C_WHITE
        size = 150 if len(num) <= 3 else 120                    # 4-5 digits get a smaller size
        num_w = int(0.70 * size * len(num))                     # DejaVu Sans Bold digit width ≈ 0.70 em
        x0 = (W - (num_w + 14 + 40)) // 2                       # centre number + "g" as one group
        p.text(x0, 200, num, size, True, colour, "w")
        p.text(x0 + num_w + 14, 200 + int(0.24 * size), "g", 60, True, C_GREEN_HI, "w")
        if s.get("overloaded"):
            p.rect(36, 300, W - 36, 352, C_RED)
            p.text(W // 2, 326, "OVERLOAD: remove weight (max 5 kg)", 20, True, C_WHITE, "center")
        elif s.get("mock"):
            p.text(120, 326, "Demo:", 16, False, C_MUTED, "e")
            for i, g in enumerate((150, 250, 320)):
                x0 = 136 + i * 120
                p.rect(x0, 306, x0 + 104, 346, C_TILE)
                p.text(x0 + 52, 326, f"{g} g", 18, True, C_WHITE, "center")
                buttons.append((x0, 306, x0 + 104, 346, f"sim:{g}"))
        else:
            p.text(W // 2, 326, s.get("hint", "Zero the empty plate, then add food"), 18, False, C_MUTED, "center")
        if s.get("address"):
            p.text(W // 2, 359, str(s["address"]), 13, False, C_GREEN_HI, "center")
        button(12, 384, 232, 468, "ZERO", C_TILE, "zero")
        button(244, 384, W - 12, 468, "CAPTURE", C_GREEN, "capture")

    elif screen == "analyzing":
        p.text(W // 2, 170, "Analyzing…", 44, True, C_GREEN_HI, "center")
        p.text(W // 2, 232, f"{s.get('weight', 0):.0f} g · please wait", 22, False, C_MUTED, "center")
        button(12, 384, W - 12, 468, "PLEASE WAIT", C_DISABLED, None, 26)

    elif screen == "result":
        name = str(s.get("food", "Unknown food"))
        if len(name) > 26:
            name = name[:25] + "…"
        p.text(W // 2, 86, name, 30, True, C_WHITE, "center")
        p.text(W // 2, 150, f"{s.get('kcal', 0):.0f} kcal", 52, True, C_GREEN_HI, "center")
        p.text(W // 2, 192, f"{s.get('weight', 0):.0f} g", 20, False, C_MUTED, "center")
        tiles = [("Carbs", s.get("carbs", 0)), ("Protein", s.get("protein", 0)),
                 ("Fat", s.get("fat", 0)), ("Sugar", s.get("sugar", 0))]
        for i, (lab, val) in enumerate(tiles):
            x0 = 24 + (i % 2) * 300
            y0 = 214 + (i // 2) * 76
            p.rect(x0, y0, x0 + 292, y0 + 68, C_TILE)
            p.text(x0 + 16, y0 + 34, lab, 20, False, C_MUTED, "w")
            p.text(x0 + 276, y0 + 34, f"{val:.1f} g", 30, True, C_WHITE, "e")
        button(12, 384, 232, 468, "DONE", C_TILE, "done")
        button(244, 384, W - 12, 468, "CAPTURE", C_GREEN, "capture")

    elif screen == "sent":
        p.text(W // 2, 150, "Photo sent to app", 40, True, C_GREEN_HI, "center")
        p.text(W // 2, 212, f"{s.get('weight', 0):.0f} g · the phone is analyzing", 22, False, C_MUTED, "center")
        p.text(W // 2, 262, "Calories appear here when it finishes", 18, False, C_MUTED, "center")
        button(12, 384, 232, 468, "DONE", C_TILE, "done")
        button(244, 384, W - 12, 468, "CAPTURE", C_GREEN, "capture")

    elif screen == "error":
        p.text(W // 2, 100, "Could not analyze", 32, True, C_RED, "center")
        for i, line in enumerate(_wrap(s.get("message", ""), 40)[:6]):
            p.text(W // 2, 160 + i * 32, line, 19, False, C_WHITE, "center")
        button(12, 384, 232, 468, "DONE", C_TILE, "done")
        button(244, 384, W - 12, 468, "TRY AGAIN", C_GREEN, "capture", 28)

    elif screen == "exit_confirm":
        p.text(W // 2, 95, "Exit Scale App?", 34, True, C_WHITE, "center")
        p.text(W // 2, 160, "Close the touchscreen interface and return", 20, False, C_MUTED, "center")
        p.text(W // 2, 195, "to the Raspberry Pi terminal prompt.", 20, False, C_WHITE, "center")
        p.text(W // 2, 255, "To restart anytime: ./start_scale_app.sh", 18, False, C_GREEN_HI, "center")
        p.text(W // 2, 295, "Press CANCEL to continue weighing", 16, False, C_MUTED, "center")
        button(12, 384, 232, 468, "CANCEL", C_TILE, "cancel_exit")
        button(244, 384, W - 12, 468, "EXIT APP", C_RED, "confirm_exit")
    return buttons


class _TkPainter:
    def __init__(self, canvas: Any) -> None:
        self.c = canvas

    def rect(self, x0: int, y0: int, x1: int, y1: int, fill: str) -> None:
        self.c.create_rectangle(x0, y0, x1, y1, fill=fill, outline=fill)

    def text(self, x: int, y: int, s: str, size: int, bold: bool, fill: str, anchor: str) -> None:
        self.c.create_text(x, y, text=s, fill=fill, anchor=anchor,
                           font=(UI_FONT, -size, "bold" if bold else "normal"))


class ScaleTouchscreenApp:
    """English touchscreen UI for the 3.5" 640x480 Waveshare DSI LCD.

    One screen at a time, large text and two large buttons:
      weigh     -> live weight (whole grams), ZERO and CAPTURE
      analyzing -> shown while the photo and weight are being analysed
      result    -> food name, calories, carbs / protein / fat / sugar, DONE and CAPTURE
      error     -> short message, DONE and TRY AGAIN
    """

    def __init__(self, hardware: ScaleHardwareAdapter, db_path: Path, port: int,
                 fullscreen: bool = False, server: Optional[str] = None) -> None:
        import tkinter as tk
        self.tk = tk
        self.hw = hardware
        self.db_path = db_path
        self.port = port
        self.server = server
        self.root = tk.Tk()
        self.root.title("Miqdar Smart Food Scale")
        self.root.geometry("640x480")
        self.root.configure(bg=C_BG)
        if fullscreen:
            self.root.attributes("-fullscreen", True)
            self.root.config(cursor="none")
        self.root.bind("<Escape>", lambda _: self.exit_app())
        self.root.bind("<q>", lambda _: self.exit_app())
        self.root.bind("<Control-c>", lambda _: self.exit_app())
        self.canvas = tk.Canvas(self.root, width=640, height=480, bg=C_BG, highlightthickness=0)
        self.canvas.pack(expand=True)
        self.canvas.bind("<Button-1>", self._on_touch)
        self.painter = _TkPainter(self.canvas)
        self.buttons: List[Tuple[int, int, int, int, str]] = []
        self.state: Dict[str, Any] = {"screen": "weigh", "weight": 0.0, "mock": self.hw.is_mock}
        self._set_status()
        self._last_drawn: Optional[Tuple] = None
        self._seen_event_id: Optional[str] = None
        self._seen_analysis_id: Optional[str] = None
        self._worker_active = False
        self._ticks = 0
        self._tick()

    # ------------------------------------------------------------- drawing
    def _set_status(self, text: Optional[str] = None, colour: str = C_GREEN_HI) -> None:
        if text is None:
            text, colour = ("● SIMULATED", C_AMBER) if self.hw.is_mock else ("● READY", C_GREEN_HI)
        self.state["status"] = (text, colour)

    def _redraw(self) -> None:
        key = tuple(sorted((k, str(v)) for k, v in self.state.items()))
        if key == self._last_drawn:
            return
        self._last_drawn = key
        self.canvas.delete("all")
        self.buttons = draw_screen(self.painter, self.state)

    def _refresh_address(self) -> None:
        """Shows the URL to type into the phone app, right on the scale."""
        tunnel_file = ROOT / "tunnel_url.txt"
        url = tunnel_file.read_text().strip() if tunnel_file.exists() else ""
        self.state["address"] = url if url.startswith("http") else f"http://{get_ip_address()}:{self.port}"

    def _follow_capture(self) -> None:
        """Mirrors every capture on this screen, whoever started it (button, phone, auto)."""
        screen = self.state["screen"]
        if screen == "exit_confirm":
            return
        if self.hw.capture_state != "idle" or self._worker_active:
            if screen != "analyzing":
                self.state.update(screen="analyzing", weight=self.hw.get_weight())
                self._set_status("● ANALYZING", C_AMBER)
            return
        event = self.hw.latest_capture_event
        if event and event["event_id"] != self._seen_event_id:
            self._seen_event_id = event["event_id"]
            if event.get("status") == "ok":
                self._show_results(event, event["weight_g"])
            elif event.get("status") == "photo":
                self.state.update(screen="sent", weight=event["weight_g"])
                self._set_status("✓ SENT TO APP", C_GREEN_HI)
            else:
                self._show_error(event.get("message", "Capture failed"))
        elif screen == "sent" and self.hw.latest_analysis and \
                self.hw.latest_analysis["event_id"] != self._seen_analysis_id:
            self._seen_analysis_id = self.hw.latest_analysis["event_id"]
            self._show_results(self.hw.latest_analysis, self.hw.latest_analysis["weight_g"])
        elif screen == "analyzing":
            self.state.update(screen="weigh")       # auto-capture of a plate with no food on it
            self._set_status()
        elif screen in ("result", "error", "sent") and self.hw.get_weight() < MIN_CAPTURE_WEIGHT_G:
            self.state.update(screen="weigh")       # plate cleared: ready for the next meal
            self._set_status()

    def _tick(self) -> None:
        self._follow_capture()
        if self._ticks % 20 == 0:
            self._refresh_address()
        self._ticks += 1
        if self.state["screen"] == "weigh":
            try:
                w = self.hw.get_weight()
                self.state["weight"] = round(w)               # whole grams on screen
                self.state["overloaded"] = self.hw.is_overloaded()
            except Exception:
                pass
        self._redraw()
        self.root.after(150, self._tick)

    def _on_touch(self, event: Any) -> None:
        for x0, y0, x1, y1, action in self.buttons:
            if x0 <= event.x <= x1 and y0 <= event.y <= y1:
                if action == "zero":
                    self.on_zero_button()
                elif action == "capture":
                    self.on_capture_button()
                elif action in ("done", "cancel_exit"):
                    self.state.update(screen="weigh")
                    self._set_status()
                elif action == "exit":
                    if self.state.get("screen") == "exit_confirm":
                        self.state.update(screen="weigh")
                        self._set_status()
                    else:
                        self.state.update(screen="exit_confirm")
                        self._set_status("● EXIT", C_RED)
                elif action == "confirm_exit":
                    self.exit_app()
                    return
                elif action.startswith("sim:"):
                    self.hw.set_sim_weight(float(action[4:]))
                self._redraw()
                return

    def exit_app(self) -> None:
        print("\n[Scale GUI] Exit requested. Closing scale UI and returning to terminal...")
        try:
            self.root.quit()
            self.root.destroy()
        except Exception:
            pass

    # ------------------------------------------------------------- actions
    def on_zero_button(self) -> None:
        self.state.update(hint="Zeroing… hold still")
        self._set_status("● ZEROING", C_AMBER)
        self._redraw()

        def work() -> None:
            ok = self.hw.tare()

            def done() -> None:
                self.state.update(hint="Zero done: add food, then CAPTURE" if ok else "Not steady: press ZERO again")
                self._set_status()
                self._redraw()
            self.root.after(0, done)
        threading.Thread(target=work, daemon=True).start()

    def on_capture_button(self) -> None:
        if self._worker_active or self.hw.capture_state != "idle":
            return
        if self.hw.is_overloaded():
            self.state.update(screen="weigh", hint="Too heavy: max 5 kg")
            self._redraw()
            return
        self._worker_active = True

        def worker() -> None:
            try:
                perform_capture(self.hw, self.db_path, server=self.server, source="scale")
            except Exception as exc:
                print(f"[Scale GUI] {exc}")         # already published; _follow_capture shows it
            finally:
                self._worker_active = False
        threading.Thread(target=worker, daemon=True).start()

    def _show_results(self, result: Dict[str, Any], grams: float) -> None:
        food = result.get("food", {})
        n = result.get("nutrients", {})
        self.state.update(screen="result", food=food.get("name_en", "Unknown food"), weight=grams,
                          kcal=n.get("calories_kcal", 0), carbs=n.get("carbohydrate_g", 0), protein=n.get("protein_g", 0),
                          fat=n.get("fat_g", 0), sugar=n.get("sugar_g", 0))
        self._set_status("✓ SAVED" if result.get("saved_to_history") else "✓ SENT TO APP", C_GREEN_HI)
        self._redraw()

    def _show_error(self, message: str) -> None:
        self.state.update(screen="error", message=message)
        self._set_status("● ERROR", C_RED)
        self._redraw()

    def run(self) -> None:
        self.root.mainloop()


# ==============================================================================
# 4. SERVICE INSTALLER (Step 6 of EE Handover: Start on Boot)
# ==============================================================================
def install_systemd_service(script_path: Path) -> None:
    """Configures systemd and desktop autostart on Raspberry Pi OS."""
    service_content = f"""[Unit]
Description=Miqdar Smart Food Scale & API Service
After=network-online.target graphical.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory={script_path.parent}
ExecStart=/usr/bin/python3 {script_path.resolve()} --fullscreen
Restart=on-failure
RestartSec=3
Environment=DISPLAY=:0
Environment=XAUTHORITY=/home/foodscale/.Xauthority

[Install]
WantedBy=graphical.target
"""
    service_path = Path("/etc/systemd/system/foodscale.service")
    try:
        service_path.write_text(service_content)
        os.system("systemctl daemon-reload")
        os.system("systemctl enable foodscale.service")
        print(f"✓ Installed systemd service to {service_path}")
        print("✓ Enabled foodscale.service to start automatically on boot.")
    except PermissionError:
        print("Error: Permission denied. Please run with sudo: sudo python3 app.py --install-service")


# ==============================================================================
# 5. HARDWARE SELF-TEST ROUTINE
# ==============================================================================
def run_self_test(hw: ScaleHardwareAdapter) -> None:
    """Executes EE verification routine for HX711 and Camera Module 3."""
    print("=" * 65)
    print("  MIQDAR SMART SCALE HARDWARE SELF-TEST")
    print("=" * 65)
    print("Keep the plate EMPTY while starting (camera warm-up ~5 s)...")
    hw.start()
    print(f"✓ Hardware started and zeroed. Live weight: {hw.get_weight():.1f} g")
    input("\n[Test 1] Place a bowl or plate on the scale, then press Enter (Zero test): ")
    t_ok = hw.tare()
    print(f"  Zero result: {'PASS' if t_ok else 'FAILED'} -> Net Weight: {hw.get_weight():.1f} g")

    input("\n[Test 2] Place a known calibration weight on the plate, then press Enter: ")
    t0 = time.monotonic()
    stable_w = hw.get_stable_weight()
    t1 = time.monotonic()
    photo_file = hw.capture_photo()
    t2 = time.monotonic()

    print(f"  Stable weight : {stable_w} g  ({t1 - t0:.2f} s to settle)")
    print(f"  Photo file    : {photo_file}  ({t2 - t1:.2f} s incl autofocus)")
    print(f"  Overloaded?   : {hw.is_overloaded()}")
    print(f"  Status        : {hw.status()}")
    print("-" * 65)
    hw.stop()
    print("Self-test completed successfully.")


# ==============================================================================
# 6. MAIN APPLICATION ENTRY POINT
# ==============================================================================
def main() -> None:
    parser = argparse.ArgumentParser(description="Miqdar Smart Food Scale & API Application")
    parser.add_argument("--fullscreen", action="store_true", help="Launch GUI in fullscreen (for 3.5\" Pi LCD)")
    parser.add_argument("--windowed", action="store_true", help="Launch GUI in 640x480 window (for desktop test)")
    parser.add_argument("--headless", action="store_true", help="Run without GUI (API server & scale service only)")
    parser.add_argument("--mock", action="store_true", help="Force simulated sensor and camera mode")
    parser.add_argument("--self-test", action="store_true", help="Run hardware self-test diagnostic")
    parser.add_argument("--install-service", action="store_true", help="Install systemd auto-start service")
    parser.add_argument("--host", default="0.0.0.0", help="API server listen host (default: 0.0.0.0)")
    parser.add_argument("--port", type=int, default=8080, help="API server port (default: 8080)")
    parser.add_argument("--db", type=Path, default=DEFAULT_DB, help="Path to miqdar_nutrition.db")
    parser.add_argument("--server", default=os.environ.get("MIQDAR_SERVER"),
                        help="Recognition server, e.g. http://192.168.137.1:8080 (Pi sends photo + weight there)")
    parser.add_argument("--analyze-on-scale", action="store_true",
                        help="Recognise on this device against the local database, instead of in the phone app")
    parser.add_argument("--auto-capture", action="store_true",
                        help="Also capture automatically when food settles on the plate")
    args = parser.parse_args()

    if args.install_service:
        install_systemd_service(Path(__file__))
        sys.exit(0)

    # Initialize Hardware Adapter
    hw = ScaleHardwareAdapter(force_mock=args.mock)

    if args.self_test:
        run_self_test(hw)
        sys.exit(0)

    hw.analyze_on_scale = bool(args.analyze_on_scale or args.server or os.environ.get("MIQDAR_ANALYZE_ON_SCALE") == "1")
    hw.start()

    # Start Embedded Background REST API Server
    api_server = start_api_server(args.host, args.port, args.db, hw, recognition_server=args.server)
    if args.server:
        print(f"[Recognition] Sending photos + weights to {args.server}")
    print(f"[API Server] Ready! Mobile app can connect to: http://{get_ip_address()}:{args.port}")

    if api_server is not None and (args.auto_capture or os.environ.get("MIQDAR_AUTO_CAPTURE") == "1"):
        hw.auto_capture = True
        AutoCaptureMonitor(hw, lambda: perform_capture(hw, args.db, server=args.server, source="auto")).start()
        print("[Auto-capture] On: food is photographed and analysed as soon as the weight settles.")

    # Check for active Cloudflare tunnel
    tunnel_file = ROOT / "tunnel_url.txt"
    if tunnel_file.exists():
        try:
            tunnel_url = tunnel_file.read_text().strip()
            if tunnel_url.startswith("http"):
                print(f"[Cloudflare Tunnel] Active public URL: {tunnel_url}")
                print(f"[Cloudflare Tunnel] Enter this URL in your mobile app settings to connect over the internet!")
        except Exception:
            pass

    app = None
    if not args.headless:
        try:
            app = ScaleTouchscreenApp(
                hardware=hw,
                db_path=args.db,
                port=args.port,
                fullscreen=args.fullscreen and not args.windowed,
                server=args.server,
            )
        except Exception as exc:                # e.g. started over SSH with no display
            print(f"[Scale GUI] No display available ({exc}). Continuing without the touchscreen.")

    try:
        if app is not None:
            app.run()
        else:
            print("[Scale] Running in headless mode. Press Ctrl+C to exit.")
            while True:
                time.sleep(1)
    except KeyboardInterrupt:
        print("\n[Scale] Stopping...")
    finally:
        hw.stop()
        if api_server is not None:
            try:
                api_server.shutdown()
            except Exception:
                pass
        print("[Scale] Application closed gracefully. Returned to terminal.")
    sys.exit(0)


if __name__ == "__main__":
    main()
