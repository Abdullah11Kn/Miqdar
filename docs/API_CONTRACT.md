# Miqdar API contract

All routes except `GET /health` accept optional prototype bearer-token protection. When `MIQDAR_API_TOKEN` is configured on the server, clients must send `Authorization: Bearer <token>`. Production deployment still requires HTTPS and proper user authentication.

## `POST /recognize`

Request:

```json
{
  "user_id": "demo-user",
  "image_base64": "...",
  "weight_g": 42,
  "hint": "medjool dates",
  "previous_image_base64": "... optional ...",
  "previous_weight_g": 0
}
```

Response contains:

- `food`: mapped predefined database food and verification state;
- `weight_g`: current weight or positive sequential delta;
- `nutrients`: calories, protein, carbohydrate, fat, sugar, fiber, sodium, potassium;
- `alerts`: projected threshold warnings;
- `timing.recognition_ms`: provider duration;
- `timing.alert_evaluation_ms`: time after recognition to complete alert evaluation;
- `timing.alert_slo_met`: true when alert evaluation is at most 4,000 ms.

The optional `hint` exists for the offline demonstrator. Production should use the configured cloud provider.

## Other routes

- `GET /health`
- `GET /foods?q=barcode-or-name`
- `GET /history?days=90&user_id=demo-user`
- `GET /goals?user_id=demo-user`
- `PUT /goals`
- `GET /health-profile?user_id=demo-user`
- `PUT /health-profile`
- `POST /meals`
- `GET /alerts?user_id=demo-user`

## `POST /recommendations`

Request:

```json
{
  "user_id": "demo-user",
  "limit": 5,
  "profile": {
    "conditions": ["diabetes", "hypertension"],
    "dietary_preferences": ["vegetarian"],
    "allergens": ["nuts"],
    "disliked_foods": ["tomato"]
  }
}
```

Supported condition keys are `diabetes`, `hypertension`, `high_cholesterol`, `weight_management`, and `kidney_disease`. Supported dietary preferences are `vegetarian` and `vegan`.

The response contains ranked database foods, suggested portions, calculated nutrients, recent-meal occurrence counts, concise reasons, the history window, and a safety disclaimer. The scoring is deterministic and auditable; Gemini is used for image classification, not for inventing health recommendations or nutrition values.
