#!/usr/bin/env python3
"""Import Saudi registered-product metadata from the official SFDA FIRS API."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import sqlite3
import sys
import urllib.parse
import urllib.request
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


DATABASE_DIR = Path(__file__).resolve().parents[1]
DEFAULT_DB = DATABASE_DIR / "miqdar_nutrition.db"
API_BASE = "https://api.sfda.gov.sa:9001/v2/FIRS/food/list"


def now_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def fetch_page(api_key: str, limit: int, offset: int) -> Any:
    query = urllib.parse.urlencode({"apikey": api_key, "limit": limit, "offset": offset})
    request = urllib.request.Request(
        f"{API_BASE}?{query}",
        headers={"Accept": "application/json", "User-Agent": "Miqdar-252/1.0"},
    )
    with urllib.request.urlopen(request, timeout=45) as response:
        return json.load(response)


def find_items(payload: Any) -> list[dict[str, Any]]:
    if isinstance(payload, list):
        return [item for item in payload if isinstance(item, dict)]
    if not isinstance(payload, dict):
        return []
    for key in ("data", "items", "results", "content", "list"):
        value = payload.get(key)
        if isinstance(value, list):
            return [item for item in value if isinstance(item, dict)]
        if isinstance(value, dict):
            nested = find_items(value)
            if nested:
                return nested
    return []


def get_value(item: dict[str, Any], *keys: str) -> str:
    folded = {key.casefold(): value for key, value in item.items()}
    for key in keys:
        value = folded.get(key.casefold())
        if value not in (None, ""):
            return str(value).strip()
    return ""


def stable_food_id(registration: str, barcode: str, trade_name: str) -> str:
    identity = registration or barcode or trade_name
    return "sfda_" + hashlib.sha1(identity.encode("utf-8")).hexdigest()[:20]


def upsert_items(connection: sqlite3.Connection, items: list[dict[str, Any]]) -> int:
    stamp = now_iso()
    written = 0
    for item in items:
        barcode = get_value(item, "barcode", "BarCode")
        registration = get_value(item, "referanceNumber", "referenceNumber", "RefNumber")
        brand = get_value(item, "brandName", "BrandName")
        trade_name = get_value(item, "tradeName", "TradeName", "itemDescription")
        if not (registration or barcode or trade_name):
            continue
        food_id = stable_food_id(registration, barcode, trade_name)
        name = trade_name or brand or f"SFDA registered product {registration}"
        package_weight = get_value(item, "itemWeight", "weight")
        try:
            package_weight_g = float(package_weight) if package_weight else None
        except ValueError:
            package_weight_g = None
        connection.execute(
            """
            INSERT INTO foods(
              food_id, canonical_name_en, canonical_name_ar, category,
              is_packaged, barcode, sfda_registration_no, brand, trade_name,
              ingredients, package_warnings, package_weight_g, source_id,
              source_record_id, source_record_url, verification_status,
              verified_at, created_at, updated_at
            ) VALUES (?, ?, '', 'SFDA registered product', 1, NULLIF(?, ''),
              NULLIF(?, ''), NULLIF(?, ''), NULLIF(?, ''), NULLIF(?, ''),
              NULLIF(?, ''), ?, 'SFDA_FIRS', NULLIF(?, ''), ?,
              'sfda_registered_nutrition_pending', ?, ?, ?)
            ON CONFLICT(food_id) DO UPDATE SET
              canonical_name_en=excluded.canonical_name_en,
              barcode=excluded.barcode,
              sfda_registration_no=excluded.sfda_registration_no,
              brand=excluded.brand,
              trade_name=excluded.trade_name,
              ingredients=excluded.ingredients,
              package_warnings=excluded.package_warnings,
              package_weight_g=excluded.package_weight_g,
              verified_at=excluded.verified_at,
              updated_at=excluded.updated_at
            """,
            (
                food_id, name, barcode, registration, brand, trade_name,
                get_value(item, "ingredientsEn", "ingredients"),
                get_value(item, "warnings"), package_weight_g, registration,
                "https://www.sfda.gov.sa/en/node/17580", stamp, stamp, stamp,
            ),
        )
        written += 1
    return written


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    parser.add_argument("--limit", type=int, default=100)
    parser.add_argument("--offset", type=int, default=0)
    parser.add_argument("--from-json", type=Path, help="Import a saved official API response offline")
    args = parser.parse_args()
    if args.from_json:
        payload = json.loads(args.from_json.read_text(encoding="utf-8"))
    else:
        api_key = os.environ.get("SFDA_API_KEY", "").strip()
        if not api_key:
            sys.exit("Set SFDA_API_KEY or use --from-json. Never commit an API key.")
        payload = fetch_page(api_key, args.limit, args.offset)
    items = find_items(payload)
    sync_id = str(uuid.uuid4())
    started = now_iso()
    with sqlite3.connect(args.db) as connection:
        connection.execute(
            "INSERT INTO sync_runs(sync_id, source_id, started_at, status, records_seen) VALUES (?, 'SFDA_FIRS', ?, 'running', ?)",
            (sync_id, started, len(items)),
        )
        written = upsert_items(connection, items)
        connection.execute(
            "UPDATE sync_runs SET completed_at=?, status='completed', records_written=? WHERE sync_id=?",
            (now_iso(), written, sync_id),
        )
        connection.commit()
    print(f"SFDA records seen={len(items)} written={written}")


if __name__ == "__main__":
    main()
