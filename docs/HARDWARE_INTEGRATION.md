# Miqdar (مقدار) - Hardware & Software Integration Guide

**Document:** `HARDWARE_INTEGRATION.md`  
**Project:** Senior Project - Smart Food Scale & Mobile System  
**Contributors:** Electrical Engineering (EE) + Software Engineering (SWE/ICS)  
**Baseline Date:** October 2026  

---

## 1. Executive Summary

This document explains the unified integration connecting the physical **Raspberry Pi 4B Smart Scale**, the **Gemini Vision AI Engine**, the **SQLite Nutrition Database**, and the **Flutter Mobile Application** into a single master application: [`app.py`](file:///Users/q2q2312345gmail.com/Documents/senior%20project%20api%20test/app.py).

The application fulfills all 6 steps required in the Electrical Engineering (EE) Handover:
1. **Screen UI (`app.py`)**: 640×480 capacitive touch interface specifically built for the Waveshare 3.5" DSI LCD (E).
2. **Hardware Binding**: Zero button bound to `hw.tare()`; Capture button bound to `hw.get_stable_weight()` and `hw.capture_photo()`.
3. **AI Vision & API**: Overhead dish JPEG and authoritative weight sent to Gemini Vision (`gemini-3.1-flash-lite`) and scaled against official Saudi FDA (SFDA) & USDA reference records.
4. **On-Screen Results**: Dish name in Arabic & English, total calories, carbs, protein, fat, and sugar.
5. **Mobile Sync**: Captured meals are automatically persisted in SQLite and immediately visible in the mobile diary. Real-time telemetry (`/scale/live`) allows the phone to mirror scale weight.
6. **Autostart on Boot**: `python3 app.py --install-service` configures the systemd background daemon and graphical autostart.

---

## 2. System Architecture & Component Mapping

```
+-----------------------------------------------------------------------------------+
|                           RASPBERRY PI 4B (foodscale)                             |
|                                                                                   |
|  [Hardware Layer - EE Handover]                                                   |
|   - 5 kg Load Cell + HX711 (Pins: 1=3.3V, 6=GND, 29=SCK/GPIO5, 31=DT/GPIO6)       |
|   - Raspberry Pi Camera Module 3 (imx708 autofocus, CSI port)                     |
|   - Waveshare 3.5" DSI Touchscreen (640x480, Goodix GT911 touch)                  |
|   - Driver Files: hardware.py, scale.py, scale_calibration.json                  |
|                                     |                                             |
|                                     v                                             |
|  [Unified Master Application: app.py]                                             |
|   +----------------------------------------------------------------------------+  |
|   | 1. Touchscreen UI (640x480):                                               |  |
|   |    - Digital Weight Readout (~10 Hz update rate)                           |  |
|   |    - Zero (Tare) Button -> hw.tare()                                       |  |
|   |    - Capture & Analyze Button -> hw.get_stable_weight() + hw.capture_photo()|  |
|   |    - Live Macro Badges (Calories, Protein, Carbs, Fat, Sugar)              |  |
|   |    - Overload Safeguard Alert (> 4.5 kg)                                   |  |
|   +----------------------------------------------------------------------------+  |
|   | 2. Embedded REST API Server (Port 8080):                                   |  |
|   |    - GET  /health      -> Server, AI status & Scale telemetry              |  |
|   |    - GET  /scale/live  -> Live weight streaming for Mobile App             |  |
|   |    - POST /scale/tare  -> Remote Zero command from Mobile App              |  |
|   |    - POST /recognize   -> Gemini Vision inference + nutrient scaling       |  |
|   |    - POST /meals       -> Log meal entry into database                     |  |
|   |    - GET  /history     -> 90-day history for Mobile App                    |  |
|   +----------------------------------------------------------------------------+  |
|                                     |                                             |
|                                     v                                             |
|  [Clinical Nutrition Database & AI]                                               |
|   - SQLite: database/miqdar_nutrition.db (SFDA & USDA verified records)           |
|   - Cloud Vision: Google Gemini Vision AI (3.1-flash-lite / 3.8-flash)             |
+-----------------------------------------------------------------------------------+
                                      ^
                                      | Wi-Fi (HTTP REST / JSON)
                                      v
+-----------------------------------------------------------------------------------+
|                        FLUTTER MOBILE CLIENT (iOS / Android)                      |
|  - Connects to: http://192.168.137.166:8080 (or local network IP)                |
|  - Real-time scale weight mirror via /scale/live                                  |
|  - Remote tare via /scale/tare                                                    |
|  - Instant diary sync for all meals measured on the physical scale                |
+-----------------------------------------------------------------------------------+
```

---

## 3. How to Run

### Mode A: On the Raspberry Pi 4B (Production Mode)

1. **Connect to the Pi**:
   ```bash
   # Laptop Wi-Fi Hotspot: name="foodscale-net", password="123456789", band=2.4 GHz
   ssh foodscale@192.168.137.166
   ```

2. **Copy `app.py` to the Pi**:
   ```bash
   scp app.py foodscale@192.168.137.166:/home/foodscale/
   ```

3. **Launch the Unified Application**:
   ```bash
   # Sudo gives real-time CPU priority to the HX711 acquisition thread
   sudo python3 app.py --fullscreen
   ```

4. **Install Auto-Start on Boot (One-Time Setup)**:
   ```bash
   sudo python3 app.py --install-service
   ```
   *The scale will now automatically start the screen application and API server whenever powered on.*

---

### Mode B: On macOS / Windows / Linux (Developer / Demo Mode)

No physical Raspberry Pi, load cell, or camera required. `app.py` detects non-Pi operating systems and starts in **Interactive Simulation Mode**:

```bash
# In the project root:
python3 app.py --windowed
```

- Opens a pixel-accurate **640×480 touchscreen simulation**.
- Displays simulated load cell telemetry with natural ±0.05g micro-fluctuations.
- Includes quick-test portion buttons (`150g`, `250g`, `320g`).
- Uses authentic sample dish photos (`kabsa.jpg`, `shawarma.jpeg`, etc.).
- Runs the background API server on `http://127.0.0.1:8080` (or `http://<YOUR_LOCAL_IP>:8080`).

---

### Mode C: Headless Server Mode

If you only need the API server and scale streaming without the GUI:
```bash
python3 app.py --headless --port 8080
```

---

### Mode D: EE Hardware Self-Test

To verify physical wiring (HX711, load cell, and Camera Module 3):
```bash
sudo python3 app.py --self-test
```

---

## 4. API Endpoints Reference

Base URL: `http://<PI_IP>:8080`

| Method | Endpoint | Description | Sample Response |
|---|---|---|---|
| `GET` | `/health` | System health, database, active AI model, and scale status | `{"status":"ok", "scale":{"mode":"real", "live_weight_g":152.3}}` |
| `GET` | `/scale/live` | Real-time weight streaming for the mobile client | `{"live_weight_g":152.3, "is_stable":true, "battery_pct":94}` |
| `POST` | `/scale/tare` | Remote zero command triggered from the mobile phone | `{"success":true, "scale":{"tare_g":152.3}}` |
| `POST` | `/scale/capture` | Triggers stable weight + camera snapshot + AI recognition + DB save | Full meal result with `meal_id`, calories, and macros |
| `POST` | `/recognize` | Food recognition on custom base64 image + portion weight | Standard Miqdar recognition JSON |
| `GET` | `/history` | 90-day meal log for the logged-in user | `{"items": [...]}` |

---

## 5. Hardware Rules & Troubleshooting Checklist

*(Derived from EE Handover Sheet 5 & 6)*

1. **Start with Plate Empty**: `hw.start()` zeroes on initial load. Keep the plate empty when switching on the scale.
2. **Tare Before Food**: Place bowl/plate -> tap **Zero (تصفير)** -> add food -> tap **Capture & Analyze**.
3. **Weight Limit (5 kg)**: Sensor maximum capacity is 5000g. Overload warning triggers at 4500g.
4. **Wiring Reference**:
   - HX711 VCC -> Pin 1 (3.3V)
   - HX711 GND -> Pin 6 (Ground)
   - HX711 SCK -> Pin 29 (GPIO5)
   - HX711 DT  -> Pin 31 (GPIO6)
   - Camera -> 15-pin CSI ribbon (silver contacts toward HDMI ports)
   - Screen -> 15-pin DSI ribbon on DISPLAY port
5. **Clean Shutdown**: Run `sudo shutdown -h now` before disconnecting the battery to protect the microSD card.
