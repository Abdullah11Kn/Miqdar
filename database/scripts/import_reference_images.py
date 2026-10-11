#!/usr/bin/env python3
"""Register only rights-documented food images in the Miqdar database."""

from __future__ import annotations

import argparse
import csv
import hashlib
import sqlite3
import uuid
from datetime import datetime, timezone
from pathlib import Path

from PIL import Image


DATABASE_DIR = Path(__file__).resolve().parents[1]
DEFAULT_DB = DATABASE_DIR / "miqdar_nutrition.db"
DEFAULT_ROOT = DATABASE_DIR / "reference_images"
ALLOWED_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}


def split_for_digest(digest: str) -> str:
    bucket = int(digest[:2], 16) % 100
    return "train" if bucket < 80 else "validation" if bucket < 90 else "test"


def truthy(value: str) -> int:
    return int(value.strip().casefold() in {"1", "true", "yes", "approved"})


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    parser.add_argument("--images-root", type=Path, default=DEFAULT_ROOT)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_ROOT / "rights.csv")
    args = parser.parse_args()

    if not args.manifest.exists():
        raise SystemExit(f"Missing rights manifest: {args.manifest}")

    with args.manifest.open("r", encoding="utf-8-sig", newline="") as handle:
        rows = list(csv.DictReader(handle))

    inserted = 0
    with sqlite3.connect(args.db) as connection:
        for row in rows:
            relative_path = Path(row["relative_path"])
            image_path = (args.images_root / relative_path).resolve()
            if args.images_root.resolve() not in image_path.parents:
                raise SystemExit(f"Path escapes image root: {relative_path}")
            if image_path.suffix.casefold() not in ALLOWED_EXTENSIONS:
                raise SystemExit(f"Unsupported image type: {image_path}")
            if not image_path.exists():
                raise SystemExit(f"Missing image: {image_path}")
            if not row["rights_holder"].strip() or not row["license_or_permission"].strip():
                raise SystemExit(f"Rights fields are required: {relative_path}")
            payload = image_path.read_bytes()
            digest = hashlib.sha256(payload).hexdigest()
            with Image.open(image_path) as image:
                width, height = image.size
            split = row.get("split", "").strip() or split_for_digest(digest)
            connection.execute(
                """
                INSERT INTO food_images(
                  image_id, food_id, relative_path, source_id, source_url,
                  rights_holder, license_or_permission, sha256, pixel_width,
                  pixel_height, split, capture_angle, lighting,
                  approved_for_model_use, created_at
                ) VALUES (?, ?, ?, ?, NULLIF(?, ''), ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(relative_path) DO UPDATE SET
                  sha256=excluded.sha256, pixel_width=excluded.pixel_width,
                  pixel_height=excluded.pixel_height, split=excluded.split,
                  approved_for_model_use=excluded.approved_for_model_use
                """,
                (
                    "img_" + uuid.uuid4().hex, row["food_id"], str(relative_path),
                    row["source_id"], row.get("source_url", ""), row["rights_holder"],
                    row["license_or_permission"], digest, width, height, split,
                    row.get("capture_angle", "unknown"), row.get("lighting", "unknown"),
                    truthy(row.get("approved_for_model_use", "")),
                    datetime.now(timezone.utc).replace(microsecond=0).isoformat(),
                ),
            )
            inserted += 1
        connection.commit()
    print(f"Registered images={inserted}")


if __name__ == "__main__":
    main()
