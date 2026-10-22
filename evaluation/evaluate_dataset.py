"""
evaluate_dataset.py - Evaluate Gemini Food Recognition Accuracy and Nutrition Extraction.

Uses the unified food_ai core to benchmark model performance across dataset images
without fallback contamination.

Usage:
  python evaluate_dataset.py [options]

Options:
  --dataset-dir PATH    Path to dataset directory (defaults to auto-detection)
  --model MODEL         Model to evaluate (default: gemini-3.1-flash-lite)
  --limit N             Evaluate only first N images
  --weight GRAMS        Weight in grams (default: 200.0)
  --delay SECONDS       Delay between API calls in seconds (default: 2.0s)
  --output-csv FILE     Path to save detailed results CSV (default: evaluation_results.csv)
"""
import argparse
import csv
import logging
import os
import re
import sys
import time
from typing import Any, Dict, List, Optional, Tuple

import warnings
warnings.filterwarnings("ignore")

from food_ai import (
    SETTINGS,
    FoodAIError,
    FoodAnalyzer,
    allowed_models,
)

# Predefined taxonomy and keywords for known foods
TAXONOMY: Dict[str, Dict[str, Any]] = {
    "رز ودجاج": {
        "name_en": "Chicken & Rice",
        "keywords_ar": [
            "رز ودجاج", "ارز ودجاج", "أرز ودجاج", "رز بالدجاج", "ارز بالدجاج", "أرز بالدجاج",
            "بخاري", "كبسة", "كبسه", "مندي", "برياني", "مجبوس", "مكبوس", "رز", "أرز", "ارز", "سليق"
        ],
        "keywords_en": [
            "chicken and rice", "chicken with rice", "bukhari", "kabsa", "kabsah",
            "mandi", "biryani", "machboos", "majboos", "rice"
        ],
    },
    "بخاري": {
        "name_en": "Bukhari Rice",
        "keywords_ar": [
            "بخاري", "رز بخاري", "أرز بخاري", "ارز بخاري", "دجاج بخاري", "رز بخاري بالدجاج",
            "كبسة", "كبسه", "مندي", "برياني", "مجبوس", "مكبوس", "رز", "أرز", "ارز",
            "دجاج مع الرز", "دجاج مع الارز", "رز بالدجاج", "ارز بالدجاج", "سليق", "صيادية", "رز ودجاج"
        ],
        "keywords_en": [
            "bukhari", "bokhari", "bukhari rice", "chicken bukhari", "kabsa", "kabsah",
            "mandi", "biryani", "machboos", "majboos", "rice", "chicken and rice", "chicken with rice"
        ],
    },
    "برجر": {
        "name_en": "Burger",
        "keywords_ar": ["برجر", "همبرجر", "همبرغر", "بورجر", "ساندويتش برجر", "ساندوتش برجر", "تشيز برجر", "بيف برجر", "ساندويتش", "ساندوتش"],
        "keywords_en": ["burger", "hamburger", "cheeseburger", "beef burger", "chicken burger", "slider", "sandwich"],
    },
    "بيتزا": {
        "name_en": "Pizza",
        "keywords_ar": ["بيتزا", "بتزا", "فطيرة بيتزا", "مناقيش", "فطيرة"],
        "keywords_en": ["pizza", "flatbread", "manakeesh"],
    },
    "جريش": {
        "name_en": "Jareesh",
        "keywords_ar": ["جريش", "جريش أحمر", "جريش ابيض", "جريش نجد", "جريش سعودي", "هريس", "قرصان", "سليق", "شوربة جريش", "قمح", "كشك", "كشك بادمجان"],
        "keywords_en": ["jareesh", "jreesh", "gareesh", "geresh", "harees", "crushed wheat", "wheat porridge", "saleeg", "kashk"],
    },
    "شاورما": {
        "name_en": "Shawarma",
        "keywords_ar": ["شاورما", "شاورمه", "شاورما دجاج", "شاورما لحم", "ساندوتش شاورما", "ساندويتش شاورما", "قص شاورما", "لفة شاورما", "دونر", "صاج", "ساندوتش"],
        "keywords_en": ["shawarma", "shawurma", "shawaarma", "doner", "shawarma sandwich", "shawarma wrap", "wrap"],
    },
    "عريكة جنوبية": {
        "name_en": "Southern Areeka",
        "keywords_ar": [
            "عريكة", "عريكه", "عريكة جنوبية", "عريكه جنوبيه", "عريكة ملكية", "عريكه ملكيه",
            "معصوب", "فتة", "فته", "حنيني", "عصيدة", "عصيده", "عصيدة تمر", "عصيده تمر"
        ],
        "keywords_en": [
            "areeka", "areekah", "arika", "arikah", "southern areeka", "erika",
            "masoub", "fatteh", "hininy", "aseeda", "asida"
        ],
    },
    "كبسة": {
        "name_en": "Kabsa",
        "keywords_ar": ["كبسة", "كبسه", "مكبوس", "مجبوس", "مندي", "بخاري", "رز", "أرز", "ارز", "رز ودجاج"],
        "keywords_en": ["kabsa", "kabsah", "machboos", "majboos", "mandi", "bukhari", "rice"],
    },
}


def normalize_arabic(text: str) -> str:
    """Normalize Arabic text for robust string matching."""
    if not text:
        return ""
    text = re.sub(r"[إأآا]", "ا", text)
    text = re.sub(r"ة", "ه", text)
    text = re.sub(r"ى", "ي", text)
    text = re.sub(r"[\u064B-\u065F]", "", text)
    return text.lower().strip()


def extract_ground_truth(filename: str) -> str:
    """Extract dish key from image filename."""
    base_name = os.path.splitext(filename)[0]
    cleaned = re.sub(r"[0-9٠-٩\s_\-\(\)]+", "", base_name).strip()
    norm_cleaned = normalize_arabic(cleaned)

    for dish_key, info in TAXONOMY.items():
        norm_key = normalize_arabic(dish_key)
        if norm_key in norm_cleaned or norm_cleaned in norm_key:
            return dish_key
        for kw in info["keywords_ar"]:
            if normalize_arabic(kw) in norm_cleaned:
                return dish_key

    return base_name


def check_match(predicted_ar: str, predicted_en: str, dish_key: str) -> bool:
    """Check if predicted food matches the ground truth dish."""
    norm_pred_ar = normalize_arabic(predicted_ar)
    pred_en_lower = (predicted_en or "").lower()

    if dish_key in TAXONOMY:
        info = TAXONOMY[dish_key]
        for kw_ar in info["keywords_ar"]:
            if normalize_arabic(kw_ar) in norm_pred_ar:
                return True
        for kw_en in info["keywords_en"]:
            if kw_en.lower() in pred_en_lower:
                return True
    else:
        if normalize_arabic(dish_key) in norm_pred_ar or dish_key.lower() in pred_en_lower:
            return True

    return False


def resolve_dataset_dir(user_path: Optional[str]) -> str:
    """Find the dataset directory automatically."""
    if user_path and os.path.exists(user_path):
        return user_path

    candidates = [
        "fooddataset",
        "dataset",
        "sample_images",
        os.path.expanduser("~/Documents/senior project api test/fooddataset"),
        os.path.expanduser("~/Documents/fooddataset"),
    ]
    for c in candidates:
        if os.path.exists(c) and os.path.isdir(c):
            return c

    return "fooddataset"


def main():
    parser = argparse.ArgumentParser(description="Evaluate Gemini Food Recognition Accuracy and Nutrition facts")
    parser.add_argument("--dataset-dir", default=None, help="Path to image dataset directory")
    parser.add_argument("--model", default="gemini-3.1-flash-lite", help="Model to evaluate (default: gemini-3.1-flash-lite)")
    parser.add_argument("--limit", type=int, default=None, help="Limit number of images (e.g. --limit 5)")
    parser.add_argument("--weight", type=float, default=200.0, help="Scale weight in grams (default: 200)")
    parser.add_argument("--delay", type=float, default=2.0, help="Delay between API calls in seconds (default: 2.0s)")
    parser.add_argument("--output-csv", default="evaluation_results.csv", help="CSV output filename")

    args = parser.parse_args()

    if args.model not in allowed_models():
        print(f"Error: Model '{args.model}' is not in allowed models: {sorted(allowed_models())}")
        sys.exit(1)

    dataset_dir = resolve_dataset_dir(args.dataset_dir)
    if not os.path.exists(dataset_dir):
        print(f"Error: Dataset directory '{dataset_dir}' does not exist.")
        sys.exit(1)

    valid_exts = (".jpg", ".jpeg", ".png", ".webp")
    image_files = sorted([
        f for f in os.listdir(dataset_dir)
        if f.lower().endswith(valid_exts) and not f.startswith(".")
    ])

    if not image_files:
        print(f"Error: No images found in '{dataset_dir}'.")
        sys.exit(1)

    if args.limit:
        image_files = image_files[:args.limit]

    total_images = len(image_files)

    print("\n" + "=" * 65)
    print("      GEMINI VISION DATASET ACCURACY & NUTRITION EVALUATION")
    print(f"  Model: {args.model}")
    print(f"  Images: {total_images} from '{dataset_dir}'")
    print(f"  Authoritative Weight: {args.weight:g} g")
    print("=" * 65 + "\n")

    analyzer = FoodAnalyzer()

    correct_count = 0
    mismatch_count = 0
    error_count = 0
    total_latency = 0.0

    per_dish_stats: Dict[str, Dict[str, int]] = {}
    results = []

    for idx, filename in enumerate(image_files, 1):
        image_path = os.path.join(dataset_dir, filename)
        ground_truth = extract_ground_truth(filename)

        if ground_truth not in per_dish_stats:
            per_dish_stats[ground_truth] = {"total": 0, "correct": 0}
        per_dish_stats[ground_truth]["total"] += 1

        print(f"[{idx:02d}/{total_images:02d}] {filename:22s} -> ", end="", flush=True)

        try:
            res = analyzer.analyze(
                source=image_path,
                weight_grams=args.weight,
                model=args.model,
                use_cache=False,
                allow_fallback=False,
            )
            total_latency += res.latency_s
            best_ar = res.analysis.best_match_ar
            best_en = res.analysis.best_match_en
            kcal_100g = res.analysis.calories_per_100g
            confidence = res.analysis.confidence

            is_correct = check_match(best_ar, best_en, ground_truth)
            if is_correct:
                correct_count += 1
                per_dish_stats[ground_truth]["correct"] += 1
                status = "CORRECT"
            else:
                mismatch_count += 1
                status = "MISMATCH"

            print(f"{status:8s} | {best_en} ({best_ar}) | {kcal_100g:.0f} kcal/100g | {res.latency_s:.2f}s")
            results.append({
                "filename": filename,
                "ground_truth": ground_truth,
                "status": status,
                "predicted_en": best_en,
                "predicted_ar": best_ar,
                "confidence": confidence,
                "calories_100g": kcal_100g,
                "protein_100g": res.analysis.protein_per_100g,
                "carbs_100g": res.analysis.carbs_per_100g,
                "fat_100g": res.analysis.fat_per_100g,
                "latency_s": round(res.latency_s, 2),
                "notes": res.analysis.nutrition_basis,
            })

        except FoodAIError as err:
            error_count += 1
            print(f"API_ERROR [{err.code}]: {err.message}")
            results.append({
                "filename": filename,
                "ground_truth": ground_truth,
                "status": "ERROR",
                "predicted_en": "N/A",
                "predicted_ar": "N/A",
                "confidence": 0,
                "calories_100g": 0,
                "protein_100g": 0,
                "carbs_100g": 0,
                "fat_100g": 0,
                "latency_s": 0,
                "notes": f"Error: {err.code} - {err.message}",
            })
        except Exception as exc:
            error_count += 1
            print(f"EXCEPTION: {exc}")
            results.append({
                "filename": filename,
                "ground_truth": ground_truth,
                "status": "ERROR",
                "predicted_en": "N/A",
                "predicted_ar": "N/A",
                "confidence": 0,
                "calories_100g": 0,
                "protein_100g": 0,
                "carbs_100g": 0,
                "fat_100g": 0,
                "latency_s": 0,
                "notes": f"Exception: {exc}",
            })

        if args.delay > 0 and idx < total_images:
            time.sleep(args.delay)

    # Summary
    evaluated = correct_count + mismatch_count
    accuracy = (correct_count / evaluated * 100) if evaluated > 0 else 0.0
    avg_latency = (total_latency / evaluated) if evaluated > 0 else 0.0

    print("\n" + "=" * 65)
    print("                    EVALUATION SUMMARY")
    print("=" * 65)
    print(f"  Total Images Processed : {total_images}")
    print(f"  Successfully Evaluated : {evaluated}")
    print(f"  Correct Identifications: {correct_count} / {evaluated} ({accuracy:.1f}%)")
    print(f"  Mismatched Predictions : {mismatch_count} / {evaluated}")
    print(f"  API / Network Errors   : {error_count}")
    print(f"  Average Latency        : {avg_latency:.2f} s")
    print("-" * 65)
    print("  Per-Dish Recognition Breakdown:")
    for dish, stats in per_dish_stats.items():
        d_tot = stats["total"]
        d_corr = stats["correct"]
        d_acc = (d_corr / d_tot * 100) if d_tot > 0 else 0.0
        en_name = TAXONOMY.get(dish, {}).get("name_en", dish)
        print(f"   * {dish:15s} ({en_name:15s}): {d_corr}/{d_tot} ({d_acc:.1f}%)")
    print("=" * 65 + "\n")

    with open(args.output_csv, "w", newline="", encoding="utf-8") as f:
        fieldnames = [
            "filename", "ground_truth", "status", "predicted_en", "predicted_ar",
            "confidence", "calories_100g", "protein_100g", "carbs_100g", "fat_100g",
            "latency_s", "notes"
        ]
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(results)

    print(f"[+] Detailed evaluation log saved to: {args.output_csv}\n")


if __name__ == "__main__":
    main()
