#!/usr/bin/env python3
"""
Quick interactive test tool for Miqdar Food Recognition & Nutrition Scaling.

Usage:
  python3 test_recognition.py
  python3 test_recognition.py evaluation/sample_images/kabsa.jpg 300
  python3 test_recognition.py evaluation/sample_images/shawarma.jpeg 180
  python3 test_recognition.py evaluation/sample_images/jareesh.jpeg 250
"""
from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

# Add backend directory to path
ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "backend"))

# Load environment
env_file = ROOT / "backend" / ".env"
if env_file.exists():
    with env_file.open() as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, v = line.split("=", 1)
                os.environ.setdefault(k.strip(), v.strip().strip('"').strip("'"))

from miqdar_backend.database import connect
from miqdar_backend.service import recognize_food


def main() -> None:
    parser = argparse.ArgumentParser(description="Test Miqdar Vision Recognition on an image")
    parser.add_argument(
        "image",
        nargs="?",
        default=str(ROOT / "evaluation" / "sample_images" / "kabsa.jpg"),
        help="Path to food image file",
    )
    parser.add_argument(
        "weight",
        nargs="?",
        type=float,
        default=250.0,
        help="Authoritative scale weight in grams (default: 250g)",
    )
    parser.add_argument("--hint", default=None, help="Optional user text hint")
    parser.add_argument("--db", default=str(ROOT / "database" / "miqdar_nutrition.db"), help="Database path")
    args = parser.parse_args()

    image_path = Path(args.image)
    if not image_path.exists():
        print(f"Error: image file '{image_path}' not found.")
        sys.exit(1)

    print("=" * 65)
    print("  MIQDAR SMART SCALE & AI FOOD RECOGNITION TEST")
    print("=" * 65)
    print(f" Image  : {image_path.name} ({image_path.stat().st_size / 1024:.1f} KB)")
    print(f" Weight : {args.weight:.1f} g (from physical scale)")
    if args.hint:
        print(f" Hint   : {args.hint}")
    print("-" * 65)

    with image_path.open("rb") as f:
        image_bytes = f.read()

    db_path = Path(args.db)
    if not db_path.exists():
        print(f"Error: Database '{db_path}' not found. Run ./run_checks.sh first.")
        sys.exit(1)

    print("Analyzing image with Gemini Vision AI + Miqdar Database...")
    with connect(db_path) as connection:
        try:
            result = recognize_food(
                connection,
                user_id="demo-user",
                image_bytes=image_bytes,
                weight_g=args.weight,
                hint=args.hint,
            )
        except Exception as exc:
            print(f"\nRecognition Failed: {type(exc).__name__}: {exc}")
            sys.exit(1)

    food = result["food"]
    nutrients = result["nutrients"]
    timing = result["timing"]

    print("\nRECOGNITION RESULT:")
    print(f"  Dish (English) : {food['name_en']}")
    print(f"  Dish (Arabic)  : {food['name_ar']}")
    print(f"  Confidence     : {result['confidence'] * 100:.1f}%")
    print(f"  Category       : {food['category']}")
    print(f"  Provider       : {result['recognition_provider']} ({result.get('recognition_model') or 'active'})")
    print(f"  Cache Status   : {'HIT (instant)' if result.get('recognition_cached') else 'MISS (live AI call)'}")
    print(f"  AI Latency     : {timing['recognition_ms']} ms")
    print(f"  Alert SLO Check: {timing['alert_evaluation_ms']} ms (Requirement <= 4,000 ms: {'PASS' if timing['alert_slo_met'] else 'FAIL'})")

    print("\nCANDIDATES RANKING (Top-3):")
    for c in result.get("candidates", []):
        mark = "✓ SELECTED" if c.get("selected") else " "
        label = c.get("label", "")
        conf = c.get("confidence", 0) * 100
        food_match = c.get("food", {}).get("name_en", "No DB match") if c.get("food") else "No DB match"
        print(f"  [{c.get('rank', 1)}] {label:<22} ({conf:4.1f}%) -> {food_match:<22} {mark}")

    print(f"\nSCALED NUTRITION ({result['weight_g']:.0f} g portion):")
    print(f"  Calories       : {nutrients['calories_kcal']:.1f} kcal")
    print(f"  Protein        : {nutrients['protein_g']:.1f} g")
    print(f"  Carbohydrates  : {nutrients['carbohydrate_g']:.1f} g")
    print(f"  Fat            : {nutrients['fat_g']:.1f} g")
    print(f"  Sugar          : {nutrients['sugar_g']:.1f} g")
    print(f"  Fiber          : {nutrients['fiber_g']:.1f} g")
    print(f"  Sodium         : {nutrients['sodium_mg']:.1f} mg")
    print(f"  Potassium      : {nutrients['potassium_mg']:.1f} mg")

    alerts = result.get("alerts", [])
    if alerts:
        print(f"\nCLINICAL ALERTS TRIGGERED ({len(alerts)}):")
        for alert in alerts:
            print(f"  ! [{alert['severity'].upper()}] {alert['message']}")
    else:
        print("\nCLINICAL ALERTS: None triggered (within healthy daily thresholds).")

    print("=" * 65)


if __name__ == "__main__":
    main()
