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

### `POST /scale/capture/outcome`
The app reports what became of a capture's meal: `{"event_id", "outcome", "food", "kcal"}`, with `outcome` one of `saved`,
`discarded`, `missing` or `failed`. The touchscreen says Saved only after this. It also clears `save_request`. Returns
`{"accepted": true}`, or `false` for an older capture.

`save_request` in `GET /scale/live` is the `event_id` of a meal whose Save to Diary was pressed on the touchscreen, or null.
The diary is on the phone, so the phone saves it and answers with the route above. With no answer in 10 s the scale withdraws
the request and says so.

`cancel_request` in `GET /scale/live` is the `event_id` of a capture cancelled on the touchscreen, or null. The phone stops
analyzing it, closes its screens and answers with `outcome: discarded`.

### `POST /scale/capture/result`
The app reports `{"event_id", "food": {"name_en"}, "nutrients", "warning"?}` so the touchscreen can show the calories.
`warning` is present only when the meal passes a limit that is harmful to pass, as one short English line such as
"Over sugar limit. Try a smaller portion."; the touchscreen draws it in red. Results for an older capture are ignored.
Returns `{"accepted": true}` or `false`.

### `POST /scale/tare`
Sets the current reading to 0 g. Returns `{"success": true, "scale": { ...same as /scale/live... }}`.

### Mixed plates

The plate is kept on the scale, and `/scale/live` reports it as `plate`: null, or
`{"plate_id", "state": "open" | "finished", "simulated", "steps": [{"index", "step_id", "reading_g", "grams"}]}`. Each food's `grams`
is the change in weight, and only the scale sets it. If the Pi restarts, an unfinished plate is lost; `/scale/live` also reports `boot_id`, which changes on a restart, so the app can say so.

- `POST /scale/plate/add` records the food added since the last step, and opens a plate if none is open. Returns `{"plate": ...}`.
- `POST /scale/plate/finish` records a last food if the weight rose, then sets `state` to `finished`.
- `POST /scale/plate/undo` removes the last food. Removing the only food closes the plate.
- `POST /scale/plate/cancel` drops the plate. The app also calls it once it has taken a finished plate.
- `GET /scale/plate/photo?step=N` returns `{"image_base64": ...}` for that step, or 404.

Refusals: 422 `EMPTY_SCALE`, `PLATE_STEP_TOO_SMALL` (under 5 g), `PLATE_WEIGHT_DROPPED`, `WEIGHT_NOT_STEADY`; 409
`PLATE_OPEN`, `CAPTURE_IN_PROGRESS`. While a plate is open, `/scale/tare` and `/scale/capture` return `PLATE_OPEN`, and automatic
capture waits.

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
