#!/usr/bin/env python3
"""Build the Miqdar SQLite database from the reviewed seed files."""

from __future__ import annotations

import argparse
import csv
import sqlite3
import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path


DATABASE_DIR = Path(__file__).resolve().parents[1]
SEED_DIR = DATABASE_DIR / "seed"
SCHEMA_PATH = DATABASE_DIR / "schema.sql"
DEFAULT_DB = DATABASE_DIR / "miqdar_nutrition.db"
DEMO_USER_ID = "demo-user"


def utc_now() -> datetime:
    return datetime.now(timezone.utc).replace(microsecond=0)


def read_csv(name: str) -> list[dict[str, str]]:
    with (SEED_DIR / name).open("r", encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle))


def build_database(db_path: Path, *, replace: bool, seed_history: bool) -> None:
    if db_path.exists():
        if not replace:
            raise SystemExit(f"Refusing to overwrite {db_path}; pass --replace explicitly.")
        db_path.unlink()

    db_path.parent.mkdir(parents=True, exist_ok=True)
    now = utc_now()
    with sqlite3.connect(db_path) as connection:
        connection.executescript(SCHEMA_PATH.read_text(encoding="utf-8"))
        import_sources(connection)
        import_foods(connection, now)
        import_aliases(connection)
        seed_demo_account(connection, now)
        if seed_history:
            seed_demo_history(connection, now)
        connection.commit()


def import_sources(connection: sqlite3.Connection) -> None:
    for row in read_csv("sources.csv"):
        connection.execute(
            """
            INSERT INTO source_registry(
              source_id, authority, dataset_name, source_type, official_url,
              license_or_terms, retrieved_at, notes
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                row["source_id"], row["authority"], row["dataset_name"],
                row["source_type"], row["official_url"],
                row["license_or_terms"], row["retrieved_at"], row["notes"],
            ),
        )


def import_foods(connection: sqlite3.Connection, now: datetime) -> None:
    stamp = now.isoformat()
    for row in read_csv("foods.csv"):
        connection.execute(
            """
            INSERT INTO foods(
              food_id, canonical_name_en, canonical_name_ar, category,
              is_packaged, source_id, source_record_id, source_record_url,
              verification_status, verified_at, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, NULLIF(?, ''), NULLIF(?, ''), ?, ?, ?, ?)
            """,
            (
                row["food_id"], row["canonical_name_en"], row["canonical_name_ar"],
                row["category"], int(row["is_packaged"]), row["source_id"],
                row["source_record_id"], row["source_record_url"],
                row["verification_status"],
                stamp if row["verification_status"] == "verified_official_record" else None,
                stamp, stamp,
            ),
        )
        connection.execute(
            """
            INSERT INTO nutrient_profiles(
              food_id, kcal_100g, protein_g_100g, carbohydrate_g_100g,
              fat_g_100g, sugar_g_100g, fiber_g_100g, sodium_mg_100g,
              potassium_mg_100g, nutrient_source_id, nutrient_source_record_id,
              verification_status, verified_at, notes
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULLIF(?, ''), ?, ?, ?)
            """,
            (
                row["food_id"], float(row["kcal_100g"]),
                float(row["protein_g_100g"]), float(row["carbohydrate_g_100g"]),
                float(row["fat_g_100g"]), float(row["sugar_g_100g"]),
                float(row["fiber_g_100g"]), float(row["sodium_mg_100g"]),
                float(row["potassium_mg_100g"]), row["nutrient_source_id"],
                row["nutrient_source_record_id"], row["nutrient_verification_status"],
                stamp if row["nutrient_verification_status"] == "verified_official_record" else None,
                row["notes"],
            ),
        )


def import_aliases(connection: sqlite3.Connection) -> None:
    for row in read_csv("aliases.csv"):
        connection.execute(
            "INSERT INTO food_aliases(food_id, alias, language) VALUES (?, ?, ?)",
            (row["food_id"], row["alias"].casefold(), row["language"]),
        )


def seed_demo_account(connection: sqlite3.Connection, now: datetime) -> None:
    stamp = now.isoformat()
    connection.execute(
        "INSERT INTO users(user_id, name, email, created_at) VALUES (?, ?, ?, ?)",
        (DEMO_USER_ID, "Jehad Hasan Alharbi", "jehad@example.com", stamp),
    )
    connection.execute(
        """
        INSERT INTO nutrition_goals(
          user_id, calories_kcal, sugar_g, sodium_mg, potassium_mg,
          carbohydrate_g, protein_g, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (DEMO_USER_ID, 2200, 50, 2300, 3500, 275, 120, stamp),
    )
    connection.execute(
        """
        INSERT INTO devices(
          device_id, user_id, display_name, paired, wifi_ssid,
          firmware_version, last_sync_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?)
        """,
        ("Miqdar-015", DEMO_USER_ID, "Miqdar-015", 1, "KFU-Lab-WiFi", "0.9.2", stamp),
    )


def nutrient_values(connection: sqlite3.Connection, food_id: str, weight_g: float) -> dict[str, float]:
    row = connection.execute(
        "SELECT * FROM nutrient_profiles WHERE food_id = ?", (food_id,)
    ).fetchone()
    columns = [column[0] for column in connection.execute(
        "SELECT * FROM nutrient_profiles LIMIT 0"
    ).description]
    profile = dict(zip(columns, row))
    scale = weight_g / 100.0
    return {
        "calories_kcal": round(profile["kcal_100g"] * scale, 2),
        "protein_g": round(profile["protein_g_100g"] * scale, 2),
        "carbohydrate_g": round(profile["carbohydrate_g_100g"] * scale, 2),
        "fat_g": round(profile["fat_g_100g"] * scale, 2),
        "sugar_g": round(profile["sugar_g_100g"] * scale, 2),
        "fiber_g": round(profile["fiber_g_100g"] * scale, 2),
        "sodium_mg": round(profile["sodium_mg_100g"] * scale, 2),
        "potassium_mg": round(profile["potassium_mg_100g"] * scale, 2),
    }


def seed_demo_history(connection: sqlite3.Connection, now: datetime) -> None:
    """Seed 91 calendar days so the >=90-day acceptance check is testable."""
    food_cycle = [
        ("food_rice_white_cooked", 180.0),
        ("food_chicken_breast_roasted", 145.0),
        ("food_hummus_prepared", 95.0),
        ("food_dates_medjool", 42.0),
        ("food_salmon_cooked", 130.0),
        ("food_egg_boiled", 100.0),
        ("food_banana_raw", 120.0),
    ]
    for day_index in range(91):
        food_id, base_weight = food_cycle[day_index % len(food_cycle)]
        weight_g = base_weight + float((day_index % 5) * 4)
        eaten_at = (now - timedelta(days=day_index)).replace(
            hour=12 + (day_index % 7), minute=15, second=0
        )
        meal_id = f"demo-meal-{day_index:03d}"
        values = nutrient_values(connection, food_id, weight_g)
        connection.execute(
            """
            INSERT INTO meals(meal_id, user_id, eaten_at, meal_type, source, created_at)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            (meal_id, DEMO_USER_ID, eaten_at.isoformat(), "Lunch", "seed", eaten_at.isoformat()),
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
                str(uuid.uuid4()), meal_id, food_id, weight_g, 0.94,
                values["calories_kcal"], values["protein_g"],
                values["carbohydrate_g"], values["fat_g"], values["sugar_g"],
                values["fiber_g"], values["sodium_mg"], values["potassium_mg"],
            ),
        )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    parser.add_argument("--replace", action="store_true")
    parser.add_argument("--no-demo-history", action="store_true")
    args = parser.parse_args()
    build_database(args.db, replace=args.replace, seed_history=not args.no_demo_history)
    print(f"Built {args.db}")


if __name__ == "__main__":
    main()
