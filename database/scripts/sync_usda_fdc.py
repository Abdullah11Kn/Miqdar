#!/usr/bin/env python3
"""Replace prototype nutrient seeds with exact official USDA FDC records."""

from __future__ import annotations

import argparse
import json
import os
import sqlite3
import sys
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


DATABASE_DIR = Path(__file__).resolve().parents[1]
DEFAULT_DB = DATABASE_DIR / "miqdar_nutrition.db"
API_ROOT = "https://api.nal.usda.gov/fdc/v1"


NUTRIENT_KEYS = {
    1008: "kcal_100g",
    1003: "protein_g_100g",
    1005: "carbohydrate_g_100g",
    1004: "fat_g_100g",
    2000: "sugar_g_100g",
    1063: "sugar_g_100g",
    1079: "fiber_g_100g",
    1093: "sodium_mg_100g",
    1092: "potassium_mg_100g",
}


def now_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def api_get(path: str, api_key: str, params: dict[str, Any] | None = None) -> Any:
    query = {"api_key": api_key, **(params or {})}
    request = urllib.request.Request(
        f"{API_ROOT}{path}?{urllib.parse.urlencode(query, doseq=True)}",
        headers={"Accept": "application/json", "User-Agent": "Miqdar-252/1.0"},
    )
    with urllib.request.urlopen(request, timeout=45) as response:
        return json.load(response)


def select_record(search_payload: dict[str, Any]) -> dict[str, Any] | None:
    foods = search_payload.get("foods") or []
    preferred = [item for item in foods if item.get("dataType") in {"Foundation", "SR Legacy"}]
    return (preferred or foods or [None])[0]


def nutrients_from_detail(detail: dict[str, Any]) -> dict[str, float]:
    values = {value: 0.0 for value in NUTRIENT_KEYS.values()}
    for entry in detail.get("foodNutrients") or []:
        nutrient = entry.get("nutrient") or {}
        nutrient_id = nutrient.get("id") or entry.get("nutrientId")
        key = NUTRIENT_KEYS.get(int(nutrient_id)) if nutrient_id is not None else None
        if key:
            amount = entry.get("amount")
            if amount is None:
                amount = entry.get("value")
            if amount is not None:
                values[key] = float(amount)
    return values


def sync_one(connection: sqlite3.Connection, food_id: str, query: str, api_key: str) -> bool:
    search = api_get(
        "/foods/search", api_key,
        {"query": query, "dataType": ["Foundation", "SR Legacy"], "pageSize": 10},
    )
    record = select_record(search)
    if not record:
        print(f"No USDA match: {food_id} ({query})", file=sys.stderr)
        return False
    fdc_id = int(record["fdcId"])
    detail = api_get(f"/food/{fdc_id}", api_key)
    nutrients = nutrients_from_detail(detail)
    stamp = now_iso()
    connection.execute(
        """
        UPDATE foods SET source_id='USDA_FDC', source_record_id=?,
          source_record_url='https://fdc.nal.usda.gov/',
          verification_status='verified_official_record', verified_at=?, updated_at=?
        WHERE food_id=?
        """,
        (str(fdc_id), stamp, stamp, food_id),
    )
    connection.execute(
        """
        UPDATE nutrient_profiles SET kcal_100g=?, protein_g_100g=?,
          carbohydrate_g_100g=?, fat_g_100g=?, sugar_g_100g=?, fiber_g_100g=?,
          sodium_mg_100g=?, potassium_mg_100g=?, nutrient_source_id='USDA_FDC',
          nutrient_source_record_id=?, verification_status='verified_official_record',
          verified_at=?, notes=? WHERE food_id=?
        """,
        (
            nutrients["kcal_100g"], nutrients["protein_g_100g"],
            nutrients["carbohydrate_g_100g"], nutrients["fat_g_100g"],
            nutrients["sugar_g_100g"], nutrients["fiber_g_100g"],
            nutrients["sodium_mg_100g"], nutrients["potassium_mg_100g"],
            str(fdc_id), stamp, f"Synced from USDA FDC: {detail.get('description', query)}", food_id,
        ),
    )
    print(f"{food_id} -> FDC {fdc_id}")
    return True


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    parser.add_argument("--food-id", action="append", help="Sync only the named local food ID")
    args = parser.parse_args()
    api_key = os.environ.get("USDA_FDC_API_KEY", "").strip()
    if not api_key:
        sys.exit("Set USDA_FDC_API_KEY. The official API guide forbids publishing API keys.")
    with sqlite3.connect(args.db) as connection:
        connection.row_factory = sqlite3.Row
        if args.food_id:
            placeholders = ",".join("?" for _ in args.food_id)
            rows = connection.execute(
                f"SELECT food_id, canonical_name_en FROM foods WHERE food_id IN ({placeholders})",
                args.food_id,
            ).fetchall()
        else:
            rows = connection.execute(
                """
                SELECT f.food_id, f.canonical_name_en FROM foods f
                JOIN nutrient_profiles n ON n.food_id=f.food_id
                WHERE n.verification_status='requires_usda_sync'
                """
            ).fetchall()
        success = sum(sync_one(connection, row["food_id"], row["canonical_name_en"], api_key) for row in rows)
        connection.commit()
    print(f"USDA records verified={success} requested={len(rows)}")


if __name__ == "__main__":
    main()
