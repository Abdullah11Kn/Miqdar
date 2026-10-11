from __future__ import annotations

import sqlite3
import time
import uuid
from datetime import datetime, timezone
from typing import Any

from .database import goals_for_user, totals_for_day


LIMIT_MAP = {
    "calories_kcal": ("calories_kcal", "Calories", "السعرات الحرارية"),
    "sugar_g": ("sugar_g", "Sugar", "السكر"),
    "sodium_mg": ("sodium_mg", "Sodium", "الصوديوم"),
    "potassium_mg": ("potassium_mg", "Potassium", "البوتاسيوم"),
    "carbohydrate_g": ("carbohydrate_g", "Carbohydrates", "الكربوهيدرات"),
}


def evaluate_alerts(
    connection: sqlite3.Connection,
    *, user_id: str, nutrients: dict[str, float], date_text: str | None = None,
    persist: bool = False, meal_id: str | None = None,
) -> tuple[list[dict[str, Any]], int]:
    start = time.perf_counter()
    date_text = date_text or datetime.now(timezone.utc).date().isoformat()
    totals = totals_for_day(connection, user_id, date_text)
    goals = goals_for_user(connection, user_id)
    alerts: list[dict[str, Any]] = []

    for nutrient_key, (goal_key, label_en, label_ar) in LIMIT_MAP.items():
        projected = float(totals.get(nutrient_key, 0)) + float(nutrients.get(nutrient_key, 0))
        threshold = float(goals[goal_key])
        if projected <= threshold:
            continue
        ratio = projected / threshold if threshold else 99.0
        severity = "critical" if ratio >= 1.25 else "warning"
        alert = {
            "alert_id": "alert_" + uuid.uuid4().hex,
            "nutrient_key": nutrient_key,
            "severity": severity,
            "current_value": round(projected, 2),
            "threshold_value": round(threshold, 2),
            "message_en": f"{label_en} would reach {projected:.0f}, above your {threshold:.0f} daily limit.",
            "message_ar": f"سيصل {label_ar} إلى {projected:.0f}، أعلى من حدك اليومي {threshold:.0f}.",
        }
        alerts.append(alert)

    elapsed_ms = max(0, round((time.perf_counter() - start) * 1000))
    if persist:
        stamp = datetime.now(timezone.utc).replace(microsecond=0).isoformat()
        for alert in alerts:
            connection.execute(
                """
                INSERT INTO health_alerts(
                  alert_id, user_id, meal_id, nutrient_key, severity,
                  current_value, threshold_value, message_en, message_ar,
                  evaluation_ms, created_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    alert["alert_id"], user_id, meal_id, alert["nutrient_key"],
                    alert["severity"], alert["current_value"], alert["threshold_value"],
                    alert["message_en"], alert["message_ar"], elapsed_ms, stamp,
                ),
            )
        connection.commit()
    for alert in alerts:
        alert["evaluation_ms"] = elapsed_ms
    return alerts, elapsed_ms
