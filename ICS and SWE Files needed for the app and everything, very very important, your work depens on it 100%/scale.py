#!/usr/bin/env python3
"""Smart Food Scale - HX711 load cell: raw test, calibration and weighing.

Wiring (Pi 4B header):
    HX711 VCC -> pin 1  (3.3 V)
    HX711 GND -> pin 6  (GND)
    HX711 DT  -> pin 31 (GPIO6)
    HX711 SCK -> pin 29 (GPIO5)

Usage:
    python3 scale.py raw         # step 2.3: raw readings, press the plate to see them change
    python3 scale.py calibrate   # step 2.4: zero + known weight -> saves calibration
    python3 scale.py weigh       # step 2.5: live weight in grams
    python3 scale.py stream 60   # step 2.6: log every sample for 60 s, check rate and data loss
    python3 scale.py pipeline 60 # step 2.7: acquisition -> calibration -> filter; readings in = readings out
"""
import gc
import json
import os
import statistics
import sys
import time
from pathlib import Path

import lgpio

DT, SCK = 6, 5                                   # BCM GPIO numbers
HERE = Path(__file__).resolve().parent          # files stay next to the script, also under sudo
CAL_FILE = HERE / "scale_calibration.json"
SATURATED = (8388607, -8388608)                  # HX711 limits: a value stuck here means a wiring fault


class HX711:
    """Minimal HX711 driver, channel A, gain 128."""

    def __init__(self, dt=DT, sck=SCK, chip=0):
        self.h = lgpio.gpiochip_open(chip)
        self.dt, self.sck = dt, sck
        lgpio.gpio_claim_input(self.h, dt)
        lgpio.gpio_claim_output(self.h, sck, 0)  # SCK low = HX711 awake
        time.sleep(0.5)

    def read_raw(self, timeout=1.0):
        # DT goes low when a new conversion is ready (10 per second)
        t0 = time.monotonic()
        while lgpio.gpio_read(self.h, self.dt):
            if time.monotonic() - t0 > timeout:
                raise TimeoutError("HX711 not ready: check VCC (pin 1), GND (pin 6), "
                                   "DT (pin 31) and SCK (pin 29)")
            time.sleep(0.001)
        # SCK must never stay high > 60 us, or the HX711 resets and loses ~4 samples.
        # Keep this loop tight and free of Python garbage-collection pauses.
        h, sck, dt, wr, rd = self.h, self.sck, self.dt, lgpio.gpio_write, lgpio.gpio_read
        gc_was_on = gc.isenabled()
        gc.disable()
        value = 0
        for _ in range(24):                      # 24 data bits, MSB first
            wr(h, sck, 1)
            value = (value << 1) | rd(h, dt)
            wr(h, sck, 0)
        wr(h, sck, 1)                            # 25th pulse: next reading = channel A, gain 128
        wr(h, sck, 0)
        if gc_was_on:
            gc.enable()
        if value & 0x800000:                     # two's complement
            value -= 0x1000000
        return value

    def read(self, n=9):
        """Median of n readings: removes the odd corrupted sample."""
        return statistics.median(self.read_raw() for _ in range(n))

    def close(self):
        lgpio.gpiochip_close(self.h)


def load_cal():
    if not CAL_FILE.exists():
        sys.exit("No calibration found. Run:  python3 scale.py calibrate")
    return json.loads(CAL_FILE.read_text())


def mode_raw(hx):
    print("Raw readings (Ctrl+C to stop). Press the plate gently: the number should change.")
    while True:
        v = hx.read(5)
        note = "   <- stuck at the limit: check the load cell wires (E+, E-, A+, A-)" if v in SATURATED else ""
        print(f"{v:>10.0f}{note}")
        time.sleep(0.3)


def mode_calibrate(hx):
    input("1) Remove everything from the plate, then press Enter ")
    offset = hx.read(25)
    print(f"   zero reading = {offset:.0f}")
    grams = float(input("2) Put the known weight on the plate, wait 3 s, "
                        "then type its mass in grams and press Enter: "))
    raw = hx.read(25)
    factor = (raw - offset) / grams
    if abs(factor) < 1:
        sys.exit("   The reading hardly changed: is the weight on the plate and the load cell mounted?")
    CAL_FILE.write_text(json.dumps({"offset": offset, "factor": factor,
                                    "cal_mass_g": grams,
                                    "date": time.strftime("%Y-%m-%d %H:%M")}, indent=2))
    print(f"   factor = {factor:.2f} counts per gram  (saved to {CAL_FILE})")
    print(f"   check: the weight now reads {(hx.read(9) - offset) / factor:.1f} g")


def mode_weigh(hx):
    cal = load_cal()
    input("Remove everything from the plate, then press Enter to zero ")
    offset = hx.read(25)
    print("Weight in grams (Ctrl+C to stop):")
    while True:
        print(f"{(hx.read(5) - offset) / cal['factor']:8.1f} g")
        time.sleep(0.2)


def mode_stream(hx, seconds=60):
    """Reads every HX711 sample, logs it to CSV and reports rate, missed samples and errors."""
    cal = json.loads(CAL_FILE.read_text()) if CAL_FILE.exists() else None
    print(f"Logging every sample for {seconds:.0f} s. Keep the plate still (empty or one fixed weight).")
    times, vals, timeouts = [], [], 0
    t_end = time.monotonic() + seconds
    while time.monotonic() < t_end:
        try:
            v = hx.read_raw(timeout=0.5)
        except TimeoutError:
            timeouts += 1
            continue
        times.append(time.monotonic())
        vals.append(v)
    if len(vals) < 10:
        sys.exit("Too few samples: check the wiring (run: python3 scale.py raw)")

    dts = [b - a for a, b in zip(times, times[1:])]
    med_dt = statistics.median(dts)
    missed = sum(round(dt / med_dt) - 1 for dt in dts if dt > 1.5 * med_dt)
    resets = sum(1 for dt in dts if dt > 3 * med_dt)   # gap of ~4 samples = HX711 reset
    factor = cal["factor"] if cal else 1.0
    unit = "g" if cal else "counts"
    centre = statistics.median(vals)
    w = [(v - centre) / factor for v in vals]
    # corrupted sample = more than 5 g away from the median of its 5 neighbours
    bad = sum(1 for i in range(2, len(w) - 2)
              if abs(w[i] - statistics.median(w[i - 2:i + 3])) > (5 if cal else 2000))

    log = HERE / "stream_log.csv"
    with log.open("w") as f:
        f.write("time_s,raw,relative_" + unit + "\n")
        for t, v, g in zip(times, vals, w):
            f.write(f"{t - times[0]:.4f},{v},{g:.3f}\n")

    expected = round((times[-1] - times[0]) / med_dt) + 1
    print(f"""
Samples received   : {len(vals)}   (expected {expected})
Sample rate        : {1 / med_dt:.2f} samples/s   (HX711 nominal: 10 or 80)
Longest gap        : {max(dts) * 1000:.0f} ms   (normal: {med_dt * 1000:.0f} ms)
Missed samples     : {missed}
Gaps (HX711 resets): {resets}
Timeouts           : {timeouts}
Corrupted samples  : {bad}   (removed by the median filter in weigh mode)
Noise (std dev)    : {statistics.stdev(w):.3f} {unit}
Log saved to       : {log}
RESULT             : {"PASS - no data loss" if missed == 0 and timeouts == 0 else "CHECK - samples were lost"}""")


def mode_pipeline(hx, seconds=60):
    """Two threads, like the final app: one acquires raw readings, one calibrates and filters them.
    Every raw reading gets a sequence number; the test proves each one is processed (in = out)."""
    import queue
    import threading
    cal = load_cal()
    offset, factor = cal["offset"], cal["factor"]
    q = queue.Queue()                            # unbounded: the acquirer never has to drop a reading
    stop = threading.Event()
    stats = {"acquired": 0, "timeouts": 0}
    rows, delays = [], []

    def acquire():                               # producer: raw readings, before calibration
        while not stop.is_set():
            try:
                v = hx.read_raw(timeout=0.5)
            except TimeoutError:
                stats["timeouts"] += 1
                continue
            stats["acquired"] += 1
            q.put((stats["acquired"], time.monotonic(), v))
        q.put(None)

    def process():                               # consumer: calibration + 5-sample median filter
        window, expected, seq_errors = [], 1, 0
        while (item := q.get()) is not None:
            seq, t, v = item
            seq_errors += seq != expected
            expected = seq + 1
            g = (v - offset) / factor
            window = (window + [g])[-5:]
            rows.append((t, seq, v, g, statistics.median(window)))
            delays.append(time.monotonic() - t)
        stats["seq_errors"] = seq_errors

    print(f"Running for {seconds:.0f} s: acquisition thread -> queue -> processing thread. Keep the plate still.")
    threads = [threading.Thread(target=acquire), threading.Thread(target=process)]
    for th in threads:
        th.start()
    try:
        time.sleep(seconds)
    finally:
        stop.set()
        for th in threads:
            th.join()

    n_in, n_out = stats["acquired"], len(rows)
    t0 = rows[0][0]
    dur = rows[-1][0] - t0
    per_sec = [0] * int(dur)
    for t, *_ in rows:
        if int(t - t0) < len(per_sec):
            per_sec[int(t - t0)] += 1
    filt = [r[4] for r in rows]
    log = HERE / "pipeline_log.csv"
    with log.open("w") as f:
        f.write("time_s,seq,raw,grams,grams_filtered\n")
        for t, seq, v, g, m in rows:
            f.write(f"{t - t0:.4f},{seq},{v},{g:.3f},{m:.3f}\n")
    ok = n_in == n_out and stats["seq_errors"] == 0
    print(f"""
Readings acquired (raw, before calibration) : {n_in}
Readings processed (calibrated + filtered)  : {n_out}
Lost between acquisition and processing     : {n_in - n_out}
Sequence errors (skipped / out of order)    : {stats["seq_errors"]}
Readings per second                         : {n_out / dur:.2f} average, {min(per_sec)}-{max(per_sec)} in any 1 s
Processing delay                            : {1000 * statistics.mean(delays):.2f} ms average, {1000 * max(delays):.2f} ms max
Weight (filtered)                           : {statistics.mean(filt):.1f} g, std dev {statistics.stdev(filt):.2f} g
Timeouts                                    : {stats["timeouts"]}
Log saved to                                : {log}
RESULT                                      : {"PASS - every reading acquired was processed" if ok else "CHECK - readings were lost"}""")


def realtime():
    """Real-time priority on its own CPU core, so Linux never pauses the read mid-sample."""
    core = max(os.sched_getaffinity(0))          # last core (core 3 on the Pi 4)
    try:
        os.sched_setaffinity(0, {core})
        os.sched_setscheduler(0, os.SCHED_FIFO, os.sched_param(50))
        print(f"Real-time priority: ON (core {core})")
    except PermissionError:
        print("Real-time priority: OFF  -> run with sudo for no data loss, e.g.  sudo python3 scale.py stream 300")


if __name__ == "__main__":
    modes = {"raw": mode_raw, "calibrate": mode_calibrate, "weigh": mode_weigh,
             "stream": mode_stream, "pipeline": mode_pipeline}
    if len(sys.argv) not in (2, 3) or sys.argv[1] not in modes:
        sys.exit(__doc__)
    realtime()
    hx = HX711()
    try:
        if len(sys.argv) == 3 and sys.argv[1] in ("stream", "pipeline"):
            modes[sys.argv[1]](hx, float(sys.argv[2]))
        else:
            modes[sys.argv[1]](hx)
    except KeyboardInterrupt:
        print("\nstopped")
    finally:
        hx.close()
