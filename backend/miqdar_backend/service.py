from __future__ import annotations

import base64
import sqlite3
import time
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from .alert_engine import evaluate_alerts
from .database import find_food_for_label, scaled_nutrients
from .recognition import configured_provider, detect_new_food, image_sha256


def decode_image(value: str | None) -> bytes:
    if not value:
        return b""
    if "," in value and value.lstrip().startswith("data:"):
        value = value.split(",", 1)[1]
    return base64.b64decode(value, validate=True)


def recognize_food(
    connection: sqlite3.Connection,
    *, user_id: str, image_bytes: bytes, weight_g: float,
    hint: str | None = None, previous_image_bytes: bytes | None = None,
    previous_weight_g: float | None = None,
) -> dict[str, Any]:
    if weight_g <= 0:
        raise ValueError("weight_g must be greater than zero")
    recognition_start = time.perf_counter()
    provider = configured_provider()
    candidates = provider.recognize(image_bytes, hint=hint)
    recognition_ms = round((time.perf_counter() - recognition_start) * 1000)
    if not candidates:
        raise LookupError("Recognition provider returned no candidates")

    matched = None
    selected = None
    for candidate in candidates:
        matched = find_food_for_label(connection, candidate.label)
        if matched:
            selected = candidate
            break
    if not matched or not selected:
        raise LookupError("No candidate maps to a predefined nutrition record")

    new_food, similarity, weight_delta = detect_new_food(
        current_bytes=image_bytes,
        previous_bytes=previous_image_bytes,
        current_weight_g=weight_g,
        previous_weight_g=previous_weight_g,
    )
    effective_weight = weight_delta if previous_weight_g is not None and new_food else weight_g
    nutrients = scaled_nutrients(matched, effective_weight)
    alerts, alert_ms = evaluate_alerts(
        connection, user_id=user_id, nutrients=nutrients, persist=False,
    )
    event_id = "event_" + uuid.uuid4().hex
    stamp = datetime.now(timezone.utc).replace(microsecond=0).isoformat()
    connection.execute(
        """
        INSERT INTO recognition_events(
          event_id, user_id, food_id, image_sha256, previous_image_sha256,
          current_weight_g, previous_weight_g, new_food_detected, confidence,
          provider, recognition_ms, alert_evaluation_ms, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            event_id, user_id, matched["food_id"], image_sha256(image_bytes),
            image_sha256(previous_image_bytes) if previous_image_bytes else None,
            weight_g, previous_weight_g, int(new_food), selected.confidence,
            provider.name, recognition_ms, alert_ms, stamp,
        ),
    )
    connection.commit()
    return {
        "event_id": event_id,
        "recognition_provider": provider.name,
        "recognition_model": getattr(provider, "model", None),
        "new_food_detected": new_food,
        "frame_similarity": similarity,
        "weight_delta_g": weight_delta,
        "food": {
            "food_id": matched["food_id"],
            "name_en": matched["canonical_name_en"],
            "name_ar": matched["canonical_name_ar"],
            "category": matched["category"],
            "verification_status": matched["verification_status"],
            "nutrient_verification_status": matched["verification_status"],
        },
        "weight_g": round(effective_weight, 2),
        "confidence": selected.confidence,
        "candidates": [candidate.__dict__ for candidate in candidates],
        "nutrients": nutrients,
        "alerts": alerts,
        "timing": {
            "recognition_ms": recognition_ms,
            "alert_evaluation_ms": alert_ms,
            "alert_slo_ms": 4000,
            "alert_slo_met": alert_ms <= 4000,
            "alert_timer_starts": "after recognition result",
        },
    }
