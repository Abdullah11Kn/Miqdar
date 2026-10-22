"""
test_food.py - Single-image CLI test for Smart Scale food recognition.

Uses the unified food_ai core, guaranteeing identical behavior to the production server.

Usage:
  python test_food.py <IMAGE_PATH> <WEIGHT_GRAMS> [options]

Examples:
  python test_food.py sample_images/kabsa.jpg 185
  python test_food.py fooddataset/برجر.jpg 240 --model gemini-3.5-flash-lite
  python test_food.py sample_images/kabsa.jpg 200 --json
"""
import argparse
import json
import os
import sys
import time

from food_ai import (
    SETTINGS,
    FoodAIError,
    allowed_models,
    analyze_food,
)


def format_cli_output(result) -> str:
    r = result.analysis
    nut = result.nutrition
    per_100 = nut["per_100g"]

    sep = "=" * 62
    sub = "-" * 62

    lines = [
        "",
        sep,
        "             SMART NUTRITION SCALE - AI ANALYSIS",
        sep,
        f"  Dish Name (EN)      : {r.best_match_en}",
        f"  Dish Name (AR)      : {r.best_match_ar}",
        f"  Preparation         : {r.preparation or 'N/A'}",
        f"  Confidence          : {r.confidence}%",
        f"  Requires Confirm?   : {'YES ⚠️' if r.requires_user_confirmation else 'NO'}",
        sub,
        f"  SCALE WEIGHT        : {result.weight_grams:g} g",
        f"  PORTION CALORIES    : {nut['calories']} kcal",
        f"  PORTION MACROS      : Protein: {nut['protein']}g | Carbs: {nut['carbs']}g | Fat: {nut['fat']}g",
        sub,
        "  NUTRITION FACTS (per 100g):",
        f"    Calories          : {per_100['calories']} kcal",
        f"    Protein           : {per_100['protein']} g",
        f"    Carbohydrates     : {per_100['carbs']} g",
        f"    Fat               : {per_100['fat']} g",
        f"    Reference Basis   : {r.nutrition_basis or 'Standard Reference'}",
        sub,
        f"  Visible Ingredients : {', '.join(r.visible_ingredients) if r.visible_ingredients else 'None noted'}",
    ]

    if r.alternatives:
        alts = [f"{a.name_en} ({a.name_ar})" for a in r.alternatives]
        lines.append(f"  Alternatives        : {'; '.join(alts)}")

    if result.warnings:
        lines.append(sub)
        lines.append("  ⚠️ Warnings:")
        for w in result.warnings:
            lines.append(f"    - {w}")

    lines.extend([
        sub,
        f"  AI Model Used       : {result.model}",
        f"  Inference Latency   : {result.latency_s:.2f} s {'(from cache)' if result.cached else ''}",
        sep,
        "",
    ])
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(
        description="Smart Nutrition Scale - Single Image Food Recognition Test"
    )
    parser.add_argument("image_path", help="Path to food image (e.g. fooddataset/برجر.jpg)")
    parser.add_argument("weight_grams", type=float, help="Scale measured weight in grams (e.g. 240)")
    parser.add_argument(
        "--model",
        default=None,
        help=f"Gemini model override (allowed: {', '.join(sorted(allowed_models()))})",
    )
    parser.add_argument(
        "--no-cache",
        action="store_true",
        help="Bypass local LRU cache and force live inference",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Print raw JSON response instead of human-readable report",
    )

    args = parser.parse_args()

    if not os.path.exists(args.image_path):
        print(f"Error: Image file not found: {args.image_path}", file=sys.stderr)
        sys.exit(1)

    if args.weight_grams <= 0 or args.weight_grams > 10000:
        print("Error: Weight must be between 0 and 10000 grams.", file=sys.stderr)
        sys.exit(1)

    if args.model and args.model not in allowed_models():
        print(f"Error: Model '{args.model}' is not in allowed models: {sorted(allowed_models())}", file=sys.stderr)
        sys.exit(1)

    try:
        result = analyze_food(
            source=args.image_path,
            weight_grams=args.weight_grams,
            model=args.model,
            use_cache=not args.no_cache,
        )

        if args.json:
            print(json.dumps(result.to_dict(), ensure_ascii=False, indent=2))
        else:
            print(format_cli_output(result))

    except FoodAIError as err:
        print(f"\n❌ Food Recognition Error [{err.code}]: {err.message}\n", file=sys.stderr)
        sys.exit(1)
    except Exception as exc:
        print(f"\n❌ Unexpected error: {exc}\n", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
