"""
compare_models.py - Side-by-side benchmark of Gemini models for the Smart Nutrition Scale.

Compares latency, recognition accuracy, and nutritional calculations across models
using the exact production food_ai pipeline (without fallback contamination).

Usage:
  python compare_models.py <IMAGE_PATH> <WEIGHT_GRAMS> [--models M1 M2 ...]

Examples:
  python compare_models.py sample_images/kabsa.jpg 185
  python compare_models.py fooddataset/برجر.jpg 240 --models gemini-3.1-flash-lite gemini-3.5-flash-lite gemini-3.8-flash
"""
import argparse
import os
import sys
import time
from typing import Any, Dict, List

from food_ai import (
    SETTINGS,
    FoodAIError,
    FoodAnalyzer,
    allowed_models,
)

try:
    from tabulate import tabulate
    HAS_TABULATE = True
except ImportError:
    HAS_TABULATE = False


DEFAULT_BENCHMARK_MODELS = [
    "gemini-3.1-flash-lite",
    "gemini-3.5-flash-lite",
    "gemini-3.8-flash",
]


def benchmark_models(image_path: str, weight_grams: float, models: List[str]) -> Dict[str, Any]:
    analyzer = FoodAnalyzer()
    results = {}

    print("\n" + "=" * 70)
    print("      GEMINI VISION NUTRITION SCALE - MODEL BENCHMARK")
    print(f"  Image: {image_path} | Measured Weight: {weight_grams:g} g")
    print("=" * 70 + "\n")

    for model_name in models:
        print(f"[*] Benchmarking {model_name:24s} ... ", end="", flush=True)
        try:
            # We disable cache and disable fallback to benchmark each model strictly on its own merits
            res = analyzer.analyze(
                source=image_path,
                weight_grams=weight_grams,
                model=model_name,
                use_cache=False,
                allow_fallback=False,
            )
            print(f"DONE in {res.latency_s:.2f}s (Confidence: {res.analysis.confidence}%)")
            results[model_name] = {"success": True, "result": res, "error": None}
        except FoodAIError as err:
            print(f"FAILED ({err.code}: {err.message})")
            results[model_name] = {"success": False, "result": None, "error": f"{err.code}: {err.message}"}
        except Exception as exc:
            print(f"FAILED (Unexpected: {exc})")
            results[model_name] = {"success": False, "result": None, "error": str(exc)}

    return results


def print_comparison_table(results: Dict[str, Any], weight_grams: float):
    models = list(results.keys())
    headers = ["Metric / Attribute"] + models

    rows = []

    # 1. Latency & Status
    rows.append(["Status"] + [
        "✅ Success" if results[m]["success"] else "❌ Failed" for m in models
    ])
    rows.append(["Response Latency"] + [
        f"{results[m]['result'].latency_s:.2f} s" if results[m]["success"] else "N/A"
        for m in models
    ])

    # 2. Recognition
    rows.append(["Dish Name (EN)"] + [
        results[m]["result"].analysis.best_match_en if results[m]["success"] else "N/A"
        for m in models
    ])
    rows.append(["Dish Name (AR)"] + [
        results[m]["result"].analysis.best_match_ar if results[m]["success"] else "N/A"
        for m in models
    ])
    rows.append(["Preparation"] + [
        results[m]["result"].analysis.preparation if results[m]["success"] else "N/A"
        for m in models
    ])
    rows.append(["Confidence"] + [
        f"{results[m]['result'].analysis.confidence}%" if results[m]["success"] else "N/A"
        for m in models
    ])
    rows.append(["Needs Confirmation?"] + [
        ("YES ⚠️" if results[m]["result"].analysis.requires_user_confirmation else "No") if results[m]["success"] else "N/A"
        for m in models
    ])

    # 3. Nutrition Facts per 100g
    rows.append(["Calories / 100g"] + [
        f"{results[m]['result'].analysis.calories_per_100g:.0f} kcal" if results[m]["success"] else "N/A"
        for m in models
    ])
    rows.append(["Protein / 100g"] + [
        f"{results[m]['result'].analysis.protein_per_100g:.1f} g" if results[m]["success"] else "N/A"
        for m in models
    ])
    rows.append(["Carbs / 100g"] + [
        f"{results[m]['result'].analysis.carbs_per_100g:.1f} g" if results[m]["success"] else "N/A"
        for m in models
    ])
    rows.append(["Fat / 100g"] + [
        f"{results[m]['result'].analysis.fat_per_100g:.1f} g" if results[m]["success"] else "N/A"
        for m in models
    ])

    # 4. Portion Calculations
    rows.append([f"Portion Calories ({weight_grams:g}g)"] + [
        f"{results[m]['result'].nutrition['calories']} kcal" if results[m]["success"] else "N/A"
        for m in models
    ])
    rows.append(["Portion Macros (P/C/F)"] + [
        f"{results[m]['result'].nutrition['protein']}g / {results[m]['result'].nutrition['carbs']}g / {results[m]['result'].nutrition['fat']}g"
        if results[m]["success"] else "N/A"
        for m in models
    ])

    # 5. Reference source
    rows.append(["Nutrition Basis"] + [
        results[m]["result"].analysis.nutrition_basis if results[m]["success"] else "N/A"
        for m in models
    ])

    # 6. Visible ingredients
    rows.append(["Visible Ingredients"] + [
        ", ".join(results[m]["result"].analysis.visible_ingredients[:5]) if results[m]["success"] else "N/A"
        for m in models
    ])

    print("\n" + "=" * 90)
    print("                              BENCHMARK SUMMARY")
    print("=" * 90)

    if HAS_TABULATE:
        print(tabulate(rows, headers=headers, tablefmt="fancy_grid"))
    else:
        for row in rows:
            print(f"\n[{row[0]}]")
            for idx, m in enumerate(models, 1):
                print(f"  {m:24s}: {row[idx]}")

    print("\n" + "=" * 90)
    print("                            ERROR DETAILS (IF ANY)")
    print("=" * 90)
    has_errors = False
    for m in models:
        if not results[m]["success"]:
            has_errors = True
            print(f"  - {m}: {results[m]['error']}")
    if not has_errors:
        print("  All models responded successfully.")
    print("=" * 90 + "\n")


def main():
    parser = argparse.ArgumentParser(
        description="Compare Gemini Vision models for Food Recognition & Nutrition calculation."
    )
    parser.add_argument("image_path", help="Path to food image")
    parser.add_argument("weight_grams", type=float, help="Scale measured weight in grams")
    parser.add_argument(
        "--models",
        nargs="+",
        default=DEFAULT_BENCHMARK_MODELS,
        help="List of model names to benchmark (default: gemini-3.1-flash-lite, gemini-3.5-flash-lite, gemini-3.8-flash)",
    )

    args = parser.parse_args()

    if not os.path.exists(args.image_path):
        print(f"Error: Image not found: {args.image_path}", file=sys.stderr)
        sys.exit(1)

    for m in args.models:
        if m not in allowed_models():
            print(f"Error: Model '{m}' is not recognized. Allowed: {sorted(allowed_models())}", file=sys.stderr)
            sys.exit(1)

    results = benchmark_models(args.image_path, args.weight_grams, args.models)
    print_comparison_table(results, args.weight_grams)


if __name__ == "__main__":
    main()
