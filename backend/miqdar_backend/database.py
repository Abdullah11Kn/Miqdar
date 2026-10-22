from __future__ import annotations

import sqlite3
import json
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


NUTRIENT_FIELDS = (
    "calories_kcal", "protein_g", "carbohydrate_g", "fat_g",
    "sugar_g", "fiber_g", "sodium_mg", "potassium_mg",
)


def connect(db_path: Path) -> sqlite3.Connection:
    connection = sqlite3.connect(db_path)
    connection.row_factory = sqlite3.Row
    connection.execute("PRAGMA foreign_keys = ON")
    connection.execute("PRAGMA busy_timeout = 5000")
    connection.execute(
        """
        CREATE TABLE IF NOT EXISTS health_profiles (
          user_id TEXT PRIMARY KEY REFERENCES users(user_id) ON DELETE CASCADE,
          conditions_json TEXT NOT NULL DEFAULT '[]',
          dietary_preferences_json TEXT NOT NULL DEFAULT '[]',
          allergens_json TEXT NOT NULL DEFAULT '[]',
          disliked_foods_json TEXT NOT NULL DEFAULT '[]',
          updated_at TEXT NOT NULL
        )
        """
    )
    return connection


def food_search(connection: sqlite3.Connection, query: str, limit: int = 30) -> list[dict[str, Any]]:
    needle = f"%{query.casefold()}%"
    rows = connection.execute(
        """
        SELECT DISTINCT f.food_id, f.canonical_name_en, f.canonical_name_ar,
          f.category, f.is_packaged, f.barcode, f.sfda_registration_no, f.brand,
          f.trade_name, f.verification_status,
          CASE WHEN n.food_id IS NULL THEN 0 ELSE 1 END AS has_nutrition
        FROM foods f
        LEFT JOIN food_aliases a ON a.food_id=f.food_id
        LEFT JOIN nutrient_profiles n ON n.food_id=f.food_id
        WHERE lower(f.canonical_name_en) LIKE ?
           OR lower(f.canonical_name_ar) LIKE ?
           OR lower(COALESCE(f.barcode, '')) LIKE ?
           OR lower(COALESCE(f.sfda_registration_no, '')) LIKE ?
           OR lower(COALESCE(a.alias, '')) LIKE ?
        ORDER BY has_nutrition DESC, f.canonical_name_en
        LIMIT ?
        """,
        (needle, needle, needle, needle, needle, limit),
    ).fetchall()
    return [dict(row) for row in rows]


def find_food_for_label(connection: sqlite3.Connection, label: str) -> dict[str, Any] | None:
    needle = label.casefold().strip()
    row = connection.execute(
        """
        SELECT f.*, n.* FROM foods f
        JOIN nutrient_profiles n ON n.food_id=f.food_id
        LEFT JOIN food_aliases a ON a.food_id=f.food_id
        WHERE lower(f.canonical_name_en)=?
           OR lower(f.canonical_name_ar)=?
           OR lower(a.alias)=?
        ORDER BY CASE WHEN n.verification_status='verified_official_record' THEN 0 ELSE 1 END
        LIMIT 1
        """,
        (needle, needle, needle),
    ).fetchone()
    if row:
        return dict(row)
    matches = food_search(connection, needle, limit=1)
    if not matches:
        return None
    row = connection.execute(
        """SELECT f.*, n.* FROM foods f JOIN nutrient_profiles n ON n.food_id=f.food_id
           WHERE f.food_id=?""",
        (matches[0]["food_id"],),
    ).fetchone()
    return dict(row) if row else None


def recognition_labels(connection: sqlite3.Connection) -> list[str]:
    """Canonical English names of active foods that have a nutrient profile.

    These are sent to the vision model as its preferred vocabulary, so a label
    copied verbatim always resolves through the exact-match branch of
    ``find_food_for_label``.
    """
    rows = connection.execute(
        """
        SELECT lower(f.canonical_name_en) AS label FROM foods f
        JOIN nutrient_profiles n ON n.food_id=f.food_id
        WHERE f.active=1 AND f.is_packaged=0
        ORDER BY f.canonical_name_en
        """
    ).fetchall()
    return [row["label"] for row in rows]


def scaled_nutrients(food: dict[str, Any], weight_g: float) -> dict[str, float]:
    scale = weight_g / 100.0
    mapping = {
        "calories_kcal": "kcal_100g",
        "protein_g": "protein_g_100g",
        "carbohydrate_g": "carbohydrate_g_100g",
        "fat_g": "fat_g_100g",
        "sugar_g": "sugar_g_100g",
        "fiber_g": "fiber_g_100g",
        "sodium_mg": "sodium_mg_100g",
        "potassium_mg": "potassium_mg_100g",
    }
    return {key: round(float(food[source]) * scale, 2) for key, source in mapping.items()}


def goals_for_user(connection: sqlite3.Connection, user_id: str) -> dict[str, Any]:
    row = connection.execute("SELECT * FROM nutrition_goals WHERE user_id=?", (user_id,)).fetchone()
    if not row:
        raise KeyError(f"Unknown user goals: {user_id}")
    return dict(row)


def update_goals(connection: sqlite3.Connection, user_id: str, values: dict[str, float]) -> dict[str, Any]:
    allowed = {
        "calories_kcal", "sugar_g", "sodium_mg", "potassium_mg",
        "carbohydrate_g", "protein_g",
    }
    current = goals_for_user(connection, user_id)
    updated = {key: float(values.get(key, current[key])) for key in allowed}
    connection.execute(
        """
        UPDATE nutrition_goals SET calories_kcal=?, sugar_g=?, sodium_mg=?,
          potassium_mg=?, carbohydrate_g=?, protein_g=?, updated_at=?
        WHERE user_id=?
        """,
        (
            updated["calories_kcal"], updated["sugar_g"], updated["sodium_mg"],
            updated["potassium_mg"], updated["carbohydrate_g"], updated["protein_g"],
            datetime.now(timezone.utc).replace(microsecond=0).isoformat(), user_id,
        ),
    )
    connection.commit()
    return goals_for_user(connection, user_id)


def totals_for_day(connection: sqlite3.Connection, user_id: str, date_text: str) -> dict[str, float]:
    select_fields = ", ".join(f"COALESCE(SUM(mi.{field}), 0) AS {field}" for field in NUTRIENT_FIELDS)
    row = connection.execute(
        f"""
        SELECT {select_fields} FROM meals m
        JOIN meal_items mi ON mi.meal_id=m.meal_id
        WHERE m.user_id=? AND date(m.eaten_at)=date(?)
        """,
        (user_id, date_text),
    ).fetchone()
    return {field: round(float(row[field]), 2) for field in NUTRIENT_FIELDS}


def history(connection: sqlite3.Connection, user_id: str, days: int) -> list[dict[str, Any]]:
    days = max(1, min(days, 3650))
    rows = connection.execute(
        """
        SELECT m.meal_id, m.eaten_at, m.meal_type, f.food_id,
          f.canonical_name_en, f.canonical_name_ar, mi.*
        FROM meals m
        JOIN meal_items mi ON mi.meal_id=m.meal_id
        JOIN foods f ON f.food_id=mi.food_id
        WHERE m.user_id=? AND date(m.eaten_at) >= date('now', ?)
        ORDER BY m.eaten_at DESC
        """,
        (user_id, f"-{days - 1} days"),
    ).fetchall()
    return [dict(row) for row in rows]


def save_meal(
    connection: sqlite3.Connection,
    *, user_id: str,
    food_id: str,
    weight_g: float,
    confidence: float,
    nutrients: dict[str, float],
    eaten_at: str | None = None,
    meal_type: str = "Meal",
) -> str:
    stamp = eaten_at or datetime.now(timezone.utc).replace(microsecond=0).isoformat()
    meal_id = "meal_" + uuid.uuid4().hex
    connection.execute(
        "INSERT INTO meals(meal_id, user_id, eaten_at, meal_type, source, created_at) VALUES (?, ?, ?, ?, 'recognition', ?)",
        (meal_id, user_id, stamp, meal_type, stamp),
    )
    connection.execute(
        """
        INSERT INTO meal_items(
          meal_item_id, meal_id, food_id, weight_g, recognition_confidence,
          calories_kcal, protein_g, carbohydrate_g, fat_g, sugar_g,
          fiber_g, sodium_mg, potassium_mg
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            "item_" + uuid.uuid4().hex, meal_id, food_id, weight_g, confidence,
            *(nutrients[field] for field in NUTRIENT_FIELDS),
        ),
    )
    connection.commit()
    return meal_id


def alerts(connection: sqlite3.Connection, user_id: str, limit: int = 100) -> list[dict[str, Any]]:
    rows = connection.execute(
        "SELECT * FROM health_alerts WHERE user_id=? ORDER BY created_at DESC LIMIT ?",
        (user_id, max(1, min(limit, 500))),
    ).fetchall()
    return [dict(row) for row in rows]


def health_profile_for_user(connection: sqlite3.Connection, user_id: str) -> dict[str, list[str]]:
    row = connection.execute(
        "SELECT * FROM health_profiles WHERE user_id=?", (user_id,)
    ).fetchone()
    if not row:
        return {
            "conditions": [],
            "dietary_preferences": [],
            "allergens": [],
            "disliked_foods": [],
        }
    return {
        "conditions": json.loads(row["conditions_json"]),
        "dietary_preferences": json.loads(row["dietary_preferences_json"]),
        "allergens": json.loads(row["allergens_json"]),
        "disliked_foods": json.loads(row["disliked_foods_json"]),
    }


def update_health_profile(
    connection: sqlite3.Connection,
    user_id: str,
    profile: dict[str, list[str]],
) -> dict[str, list[str]]:
    stamp = datetime.now(timezone.utc).replace(microsecond=0).isoformat()
    connection.execute(
        """
        INSERT INTO health_profiles(
          user_id, conditions_json, dietary_preferences_json,
          allergens_json, disliked_foods_json, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?)
        ON CONFLICT(user_id) DO UPDATE SET
          conditions_json=excluded.conditions_json,
          dietary_preferences_json=excluded.dietary_preferences_json,
          allergens_json=excluded.allergens_json,
          disliked_foods_json=excluded.disliked_foods_json,
          updated_at=excluded.updated_at
        """,
        (
            user_id,
            json.dumps(profile["conditions"]),
            json.dumps(profile["dietary_preferences"]),
            json.dumps(profile["allergens"]),
            json.dumps(profile["disliked_foods"]),
            stamp,
        ),
    )
    connection.commit()
    return health_profile_for_user(connection, user_id)
