#!/usr/bin/env python3
"""Smart Food Scale - hardware interface for the app (EE handover).

The app only needs these calls:

    import hardware as hw

    hw.start()                    # once, at app start-up (plate empty: it also zeroes)
    hw.get_weight()               # -> 152.3   live weight in grams, for the display
    hw.get_stable_weight()        # -> 152.3   waits until the reading is steady (Capture button)
    hw.tare()                     # Zero button: current load (bowl/plate) becomes 0 g
    hw.capture_photo()            # -> "/home/foodscale/photos/meal_20261020_061530.jpg"
    hw.is_overloaded()            # -> True when the sensor carries more than 4.5 kg
    hw.stop()                     # at app exit

Self-test:  python3 hardware.py      (sudo python3 hardware.py = real-time load-cell reading)

Needs in the same folder: scale.py (HX711 driver) and scale_calibration.json
(made with:  python3 scale.py calibrate).
"""
import json
import os
import statistics
import threading
import time
from collections import deque
from pathlib import Path

from scale import CAL_FILE, HERE, HX711

CAPACITY_G = 5000            # load cell rating: plate + bowl + food on the sensor
OVERLOAD_G = 4500            # warn above this (90 % of capacity)
PHOTO_DIR = HERE / "photos"
PHOTO_SIZE = (2304, 1296)    # 3 MP: plenty for food recognition, fast to upload. Max: (4608, 2592)

_lock = threading.Lock()
_samples = deque(maxlen=50)  # last ~5 s of (time, grams from calibration zero)
_state = {"tare": 0.0, "running": False, "read": 0, "errors": 0}
_thread = None
_hx = None
_cam = None
_factor = None
_zero_raw = None


# ---------------------------------------------------------------- load cell
def _acquire():
    """Background thread: reads every HX711 sample (about 10 per second)."""
    try:                                          # real-time priority for this thread only
        os.sched_setaffinity(0, {max(os.sched_getaffinity(0))})
        os.sched_setscheduler(0, os.SCHED_FIFO, os.sched_param(50))
    except (PermissionError, OSError):
        pass                                      # still works, rare sensor restarts possible
    while _state["running"]:
        try:
            raw = _hx.read_raw(timeout=0.5)
        except TimeoutError:
            _state["errors"] += 1
            continue
        g = (raw - _zero_raw) / _factor
        with _lock:
            _samples.append((time.monotonic(), g))
            _state["read"] += 1


def _recent(seconds, since=0.0):
    now = time.monotonic()
    with _lock:
        return [g for t, g in _samples if now - t <= seconds and t >= since]


def _gross():
    """Total load on the sensor (plate + bowl + food), grams, median of last 5 samples."""
    with _lock:
        last = [g for _, g in list(_samples)[-5:]]
    if not last:
        raise RuntimeError("No load-cell data: call hw.start() and check the HX711 wiring")
    return statistics.median(last)


def get_weight():
    """Live net weight in grams (after Zero). Updates about 10 times per second."""
    return round(_gross() - _state["tare"], 1)


def _wait_stable(tolerance_g, window_s, timeout_s):
    """Uses only samples taken after the call, so a tap right after placing food
    never returns the old weight. Minimum wait = window_s."""
    t_call = time.monotonic()
    t_end = t_call + timeout_s
    need = max(5, int(window_s * 8))              # ~10 samples/s -> at least 80 % of the window
    while time.monotonic() < t_end:
        vals = _recent(window_s, since=t_call)
        if len(vals) >= need and max(vals) - min(vals) <= 2 * tolerance_g:
            return statistics.mean(vals)
        time.sleep(0.1)
    return None


def get_stable_weight(tolerance_g=1.0, window_s=1.0, timeout_s=5.0):
    """Net weight once the reading stays within +/- tolerance_g for window_s seconds.
    Returns None if it never settles within timeout_s (food still moving)."""
    g = _wait_stable(tolerance_g, window_s, timeout_s)
    return None if g is None else round(g - _state["tare"], 1)


def tare(timeout_s=5.0):
    """Zero button: the current load (empty plate, bowl) becomes 0 g. Returns True if done."""
    g = _wait_stable(1.0, 1.0, timeout_s)
    if g is None:
        return False
    _state["tare"] = g
    return True


def is_overloaded():
    """True when plate + bowl + food on the sensor exceed 4.5 kg (capacity 5 kg)."""
    return _gross() > OVERLOAD_G


def is_stable(tolerance_g=1.0, window_s=1.0):
    """True when the last window_s seconds stayed within +/- tolerance_g. Never blocks."""
    vals = _recent(window_s)
    return len(vals) >= max(5, int(window_s * 8)) and max(vals) - min(vals) <= 2 * tolerance_g


# ---------------------------------------------------------------- camera
def _camera():
    global _cam
    if _cam is None:
        os.environ.setdefault("LIBCAMERA_LOG_LEVELS", "*:WARN")   # hide libcamera INFO lines
        from picamera2 import Picamera2           # installed with Raspberry Pi OS
        _cam = Picamera2()
        _cam.configure(_cam.create_still_configuration(main={"size": PHOTO_SIZE}))
        _cam.start()
        time.sleep(1)                             # exposure and white balance settle
    return _cam


def capture_photo(path=None):
    """Autofocus, then save a JPEG. Returns the file path (str)."""
    cam = _camera()
    cam.autofocus_cycle()                         # Camera Module 3: focus on the plate
    if path is None:
        PHOTO_DIR.mkdir(exist_ok=True)
        path = PHOTO_DIR / time.strftime("meal_%Y%m%d_%H%M%S.jpg")
    cam.capture_file(str(path))
    return str(path)


def release_camera():
    """Frees the camera so the rpicam-still / libcamera-still fallback can open it."""
    global _cam
    if _cam:
        try:
            _cam.stop()
            _cam.close()
        finally:
            _cam = None


# ---------------------------------------------------------------- start / stop
def start(zero=True, camera=True):
    """Start the load-cell thread, warm up the camera (so the first photo is fast)
    and zero with the plate empty."""
    global _thread, _hx, _factor, _zero_raw
    if _state["running"]:
        return
    if not CAL_FILE.exists():
        raise RuntimeError("No calibration: run  python3 scale.py calibrate")
    cal = json.loads(CAL_FILE.read_text())
    _factor, _zero_raw = cal["factor"], cal["offset"]
    _hx = HX711()
    _state["running"] = True
    _thread = threading.Thread(target=_acquire, daemon=True)
    _thread.start()
    if camera:
        try:
            _camera()                             # camera start-up (~5 s) happens here, not on Capture
        except Exception as exc:                  # the load cell must keep working without picamera2
            print(f"[Hardware] picamera2 unavailable ({exc}). Photos will use rpicam-still.")
            release_camera()
    else:
        time.sleep(1)                             # first load-cell samples
    if zero:
        tare()


def stop():
    global _cam
    _state["running"] = False
    if _thread:
        _thread.join(timeout=2)
    if _hx:
        _hx.close()
    if _cam:
        _cam.stop()
        _cam.close()
        _cam = None


def status():
    """Diagnostics: samples read, read errors, current tare (grams)."""
    return dict(read=_state["read"], errors=_state["errors"], tare_g=round(_state["tare"], 1))


# ---------------------------------------------------------------- self-test
if __name__ == "__main__":
    print("Hardware self-test. Keep the plate EMPTY while it starts (camera warm-up ~5 s)...")
    start()
    print(f"  started, zeroed. Live weight: {get_weight():.1f} g")
    input("1) Put a bowl or plate on the scale, then press Enter (Zero button test) ")
    print("   Zero:", "OK" if tare() else "FAILED - reading not steady", f"-> {get_weight():.1f} g")
    input("2) Put a known weight in it, then press Enter (Capture button test) ")
    t0 = time.monotonic()
    w = get_stable_weight()
    t1 = time.monotonic()
    p = capture_photo()
    t2 = time.monotonic()
    print(f"   stable weight : {w} g   ({t1 - t0:.1f} s to settle)")
    print(f"   photo         : {p}   ({t2 - t1:.1f} s incl. autofocus)")
    print(f"   overload      : {is_overloaded()}")
    print(f"   status        : {status()}")
    stop()
    print("Done.")
