#!/usr/bin/env python3
"""Download the CC BY 4.0 UCI Ajwa/Medjool image set after explicit acceptance."""

from __future__ import annotations

import argparse
import csv
import shutil
import urllib.request
import zipfile
from pathlib import Path


DATABASE_DIR = Path(__file__).resolve().parents[1]
IMAGE_ROOT = DATABASE_DIR / "reference_images"
ARCHIVE_URL = "https://archive.ics.uci.edu/static/public/879/ajwa+or+medjool.zip"


def safe_extract(archive: zipfile.ZipFile, destination: Path) -> None:
    destination = destination.resolve()
    for member in archive.infolist():
        target = (destination / member.filename).resolve()
        if destination not in target.parents and target != destination:
            raise RuntimeError(f"Unsafe archive member: {member.filename}")
    archive.extractall(destination)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--accept-cc-by-4", action="store_true")
    args = parser.parse_args()
    if not args.accept_cc_by_4:
        raise SystemExit("Review the UCI dataset page and pass --accept-cc-by-4 to continue.")
    downloads = IMAGE_ROOT / "_downloads"
    downloads.mkdir(parents=True, exist_ok=True)
    archive_path = downloads / "uci_ajwa_medjool.zip"
    print("Downloading about 298 MB from UCI...")
    urllib.request.urlretrieve(ARCHIVE_URL, archive_path)
    extracted = downloads / "uci_ajwa_medjool"
    extracted.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(archive_path) as archive:
        safe_extract(archive, extracted)

    mappings = {"Ajwa": "food_dates_ajwa", "Medjool": "food_dates_medjool"}
    rows: list[dict[str, str]] = []
    for source_dir_name, food_id in mappings.items():
        for source in extracted.rglob(f"{source_dir_name}/*"):
            if source.suffix.casefold() not in {".jpg", ".jpeg", ".png", ".webp"}:
                continue
            target_dir = IMAGE_ROOT / food_id
            target_dir.mkdir(parents=True, exist_ok=True)
            target = target_dir / source.name
            if not target.exists():
                shutil.copy2(source, target)
            rows.append({
                "relative_path": str(target.relative_to(IMAGE_ROOT)),
                "food_id": food_id,
                "source_id": "UCI_DATES",
                "source_url": "https://archive.ics.uci.edu/dataset/879/ajwa%2Bor%2Bmedjool",
                "rights_holder": "Ghassan F. Bati / UCI ML Repository",
                "license_or_permission": "CC BY 4.0; preserve dataset citation",
                "approved_for_model_use": "yes",
                "capture_angle": "dataset",
                "lighting": "dataset",
                "split": "",
            })
    manifest = IMAGE_ROOT / "rights.csv"
    with manifest.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)
    print(f"Prepared {len(rows)} images and {manifest}")


if __name__ == "__main__":
    main()
