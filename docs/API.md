# Miqdar scale API

The REST API served by `app.py` on the Raspberry Pi, at `http://foodscale.local:8080` by default. Checked against the
code on 2026-11-02. If this page and `app.py` disagree, `app.py` is right.

**Access:** `GET /health` and `GET /scale/live` are always open. When `MIQDAR_API_TOKEN` is set on the Pi, every other
route needs `Authorization: Bearer <token>`.

## What the app uses

### `GET /scale/live`
Polled every 500 ms. It never contains the photo.

```json
{
  "mode": "real",
  "live_weight_g": 245.8,
  "is_stable": true,
  "is_overloaded": false,
  "sensor_ok": true,
  "sensor_error": null,
  "tare_g": 0.0,
  "capacity_g": 5000,
  "capture_state": "idle",
  "auto_capture": false,
  "latest_capture": {"event_id": "cap-1-1730412345", "age_s": 2.4, "status": "photo", "weight_g": 245.8}
}
```

- `mode` is `real` or `simulated`.
- `capture_state` is `idle`, `settling`, `capturing` or `analyzing`.
- A failed capture has `"status": "error"` plus `error` and `message` in `latest_capture`.

### `POST /scale/capture`
Weighs and photographs what is on the plate. Optional body: `{"hint": "no sauce", "save": false}`.

By default the Pi does not analyze the photo. It returns the photo for the app to send to Gemini:

```json
{
  "status": "photo",
  "event_id": "cap-1-1730412345",
  "source": "phone",
  "simulated": false,
  "weight_g": 245.8,
  "image_base64": "/9j/4AAQ..."
}
```

Errors look like `{"error": "<code>", "message": "...", "candidates": [], "event_id": "..."}`:

| Code | HTTP | Meaning |
|---|---|---|
| `EMPTY_SCALE` | 422 | Nothing on the plate |
| `WEIGHT_NOT_STEADY` | see `app.py` | The weight never settled |
| `CAMERA_UNAVAILABLE` | 503 | The camera did not respond |
| `CAPTURE_IN_PROGRESS` | 409 | Another capture is running |
| `NOT_FOOD`, `FOOD_NOT_IN_DATABASE`, `AI_PROVIDER_UNAVAILABLE` | 422, 422, 502 | Only with `--analyze-on-scale` or `--server` |

### `GET /scale/capture/latest`
The full latest capture including `image_base64`. Clients fetch it once per new `event_id`. Returns 404
`NO_CAPTURE_YET` when there is none.

### `POST /scale/capture/result`
The app reports `{"event_id", "food": {"name_en"}, "nutrients"}` so the touchscreen can show the calories. Results for
an older capture are ignored. Returns `{"accepted": true}` or `false`.

### `POST /scale/tare`
Sets the current reading to 0 g. Returns `{"success": true, "scale": { ...same as /scale/live... }}`.

### `GET /health`
`{"status": "ok", "database": "miqdar_nutrition.db", "recognition": {"provider": "gemini-in-app", "configured": true}, "scale": { ... }}`

### `POST /scale/simulate`
Simulation only; returns 404 on a real scale. `{"weight_g": 240, "sample": "jareesh"}` puts food on the simulated plate.
Samples: `kabsa`, `shawarma`, `jareesh`, `pizza`, `burger`.

## Database routes

These use the Pi's food database. The default scale flow does not need them; the app uses `/recommendations`, and
`/goals`, `/health-profile` and `/meals` as best-effort copies.

| Method | Route | Purpose |
|---|---|---|
| `POST` | `/recognize` | Old path: Gemini on the server. `{"user_id", "image_base64", "weight_g", "hint"}` |
| `GET` | `/foods?q=` | Search the food list |
| `GET` | `/history?days=90&user_id=` | Meals stored on the server |
| `POST` | `/meals` | Store a meal |
| `GET`, `PUT` | `/goals` | Daily goals |
| `GET`, `PUT` | `/health-profile` | Conditions, diet, allergies, disliked foods |
| `GET` | `/alerts?user_id=` | Stored notices |
| `POST` | `/recommendations` | Ranked meal ideas. `{"user_id", "limit", "profile"}` |

`profile.conditions` can hold `diabetes`, `hypertension`, `high_cholesterol`, `weight_management`, `kidney_disease`;
`profile.dietary_preferences` can hold `vegetarian`, `vegan`.
