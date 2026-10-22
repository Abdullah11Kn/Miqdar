from __future__ import annotations

import base64
import binascii
import sqlite3
import time
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from .alert_engine import evaluate_alerts
from .database import find_food_for_label, recognition_labels, scaled_nutrients
from .recognition import Candidate, configured_provider, detect_new_food, image_sha256


class RecognitionError(Exception):
    """A classified recognition failure the API can report to the app.

    ``code`` is a stable machine-readable value the Flutter app can switch on;
    ``http_status`` is what the REST layer returns.
    """

    code = "RECOGNITION_FAILED"
    http_status = 500

    def __init__(self, message: str, *, candidates: list[Candidate] | None = None) -> None:
        super().__init__(message)
        self.candidates = candidates or []

    def to_dict(self) -> dict[str, Any]:
        return {
            "error": self.code,
            "message": str(self),
            "candidates": [candidate.__dict__ for candidate in self.candidates],
        }


class InvalidImageError(RecognitionError):
    code = "INVALID_IMAGE"
    http_status = 400


class NotFoodError(RecognitionError):
    code = "NOT_FOOD"
    http_status = 422


class UnmappedFoodError(RecognitionError):
    code = "FOOD_NOT_IN_DATABASE"
    http_status = 422


class ProviderUnavailableError(RecognitionError):
    code = "AI_PROVIDER_UNAVAILABLE"
    http_status = 502


def decode_image(value: str | None) -> bytes:
    if not value:
        return b""
    if "," in value and value.lstrip().startswith("data:"):
        value = value.split(",", 1)[1]
    try:
        return base64.b64decode(value, validate=True)
    except (binascii.Error, ValueError) as exc:
        raise InvalidImageError("image_base64 is not valid base64") from exc


def _food_summary(food: dict[str, Any]) -> dict[str, Any]:
    return {
        "food_id": food["food_id"],
        "name_en": food["canonical_name_en"],
        "name_ar": food["canonical_name_ar"],
        "category": food["category"],
        "verification_status": food["verification_status"],
    }


def recognize_food(
    connection: sqlite3.Connection,
    *, user_id: str, image_bytes: bytes, weight_g: float,
    hint: str | None = None, previous_image_bytes: bytes | None = None,
    previous_weight_g: float | None = None,
) -> dict[str, Any]:
    if weight_g <= 0:
        raise ValueError("weight_g must be greater than zero")
    hint = (hint or "").strip() or None

    provider = configured_provider()
    if hasattr(provider, "canonical_labels"):
        # Keep the AI's label vocabulary in sync with whatever is in the database.
        labels = recognition_labels(connection)
        if labels:
            provider.canonical_labels = tuple(labels)  # type: ignore[attr-defined]

    recognition_start = time.perf_counter()
    try:
        candidates = provider.recognize(image_bytes, hint=hint)
    except ValueError as exc:
        raise InvalidImageError(str(exc)) from exc
    except RuntimeError as exc:
        raise ProviderUnavailableError(str(exc)) from exc
    recognition_ms = round((time.perf_counter() - recognition_start) * 1000)
    if not candidates:
        raise ProviderUnavailableError("Recognition provider returned no candidates")
    if candidates[0].label in {"not food", "no food", "non-food"}:
        raise NotFoodError("No food was detected in the photo", candidates=candidates)

    # Map every candidate to the database so the app can offer Top-2/Top-3 as
    # one-tap corrections without another AI call.
    mapped: list[tuple[Candidate, dict[str, Any] | None]] = [
        (candidate, find_food_for_label(connection, candidate.label)) for candidate in candidates
    ]
    selected, matched = next(((c, f) for c, f in mapped if f), (None, None))
    if not matched or not selected:
        raise UnmappedFoodError(
            "The AI recognised the food, but none of its candidates exist in the "
            "Miqdar nutrition database",
            candidates=candidates,
        )

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

    candidate_payload = []
    for rank, (candidate, food) in enumerate(mapped, start=1):
        entry: dict[str, Any] = {
            "rank": rank,
            "label": candidate.label,
            "confidence": candidate.confidence,
            "selected": candidate is selected,
            "food": _food_summary(food) if food else None,
        }
        if food:
            entry["nutrients"] = scaled_nutrients(food, effective_weight)
        candidate_payload.append(entry)

    return {
        "event_id": event_id,
        "recognition_provider": provider.name,
        "recognition_model": getattr(provider, "last_model_used", None) or getattr(provider, "model", None),
        "recognition_cached": bool(getattr(provider, "last_cache_hit", False)),
        "hint_used": hint,
        "new_food_detected": new_food,
        "frame_similarity": similarity,
        "weight_delta_g": weight_delta,
        "food": {
            **_food_summary(matched),
            "nutrient_verification_status": matched["verification_status"],
        },
        "weight_g": round(effective_weight, 2),
        "confidence": selected.confidence,
        "candidates": candidate_payload,
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
