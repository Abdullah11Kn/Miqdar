#!/usr/bin/env python3
"""Scores a food-addition trial log and prints the result table, as it would be shown.

    python3 evaluation/addition_trials/score_trials.py evaluation/addition_trials/template.csv
    python3 evaluation/addition_trials/score_trials.py my_trials.csv --out report.md

A trial passes only when the addition was detected, saved as the correct food, and saved exactly once.
The requirement is at least 90% (18 of 20). Files whose name or first line says SIMULATED are labelled
as such on every output, so an example can never be mistaken for a measurement.
"""
from __future__ import annotations

import argparse
import csv
import math
import sys
from collections import defaultdict
from pathlib import Path

REQUIRED = ["trial", "meal", "food_added", "food_already_on_plate", "added_mass_g", "detected",
            "saved_as", "correct_food", "entries_saved", "notes"]
MIN_MASS_G = 20.0
TARGET = 0.90


def yes(value: str) -> bool:
    return value.strip().lower() in {"yes", "y", "true", "1", "pass"}


def wilson(passed: int, total: int, z: float = 1.96) -> tuple[float, float]:
    """95% interval for the true rate: how sure 20 trials can make anyone."""
    if total == 0:
        return 0.0, 0.0
    p = passed / total
    centre = (p + z * z / (2 * total)) / (1 + z * z / total)
    half = z * math.sqrt(p * (1 - p) / total + z * z / (4 * total * total)) / (1 + z * z / total)
    return max(0.0, centre - half), min(1.0, centre + half)


def load(path: Path) -> tuple[list[dict[str, str]], bool]:
    text = path.read_text(encoding="utf-8").splitlines()
    simulated = "SIMULATED" in path.name.upper() or (bool(text) and "SIMULATED" in text[0].upper())
    rows = list(csv.DictReader(line for line in text if not line.lstrip().startswith("#")))
    missing = [c for c in REQUIRED if rows and c not in rows[0]]
    if missing:
        sys.exit(f"Missing columns: {', '.join(missing)}")
    return rows, simulated


def judge(row: dict[str, str]) -> tuple[bool, str]:
    """Pass, or the first reason it failed."""
    try:
        mass = float(row["added_mass_g"])
    except ValueError:
        return False, "no added mass written"
    if mass < MIN_MASS_G:
        return False, f"under {MIN_MASS_G:.0f} g, not a valid trial"
    if not yes(row["detected"]):
        return False, "missed: not detected"
    if not yes(row["correct_food"]):
        return False, f"wrong food: saved as {row['saved_as'] or 'nothing'}"
    entries = row["entries_saved"].strip()
    if entries != "1":
        return False, "duplicate entry" if entries not in ("", "0") else "not saved"
    return True, ""


def _pct(n: int, d: int) -> str:
    return f"{n / d * 100:.1f}% ({n}/{d})" if d else "none"


def report(rows: list[dict[str, str]], simulated: bool, source: str) -> str:
    """The full report, laid out like evaluation/EVALUATION_400_REPORT.md."""
    filled = [r for r in rows if r["food_added"].strip()]
    banner = ("> **SIMULATED EXAMPLE, NOT MEASURED.** These rows were invented to show the format of the report. "
              "They are not results and must never be presented as results.\n\n" if simulated else "")
    if not filled:
        return banner + f"`{source}` has no filled trials yet.\n"

    judged = [(r, *judge(r)) for r in filled]
    total = len(judged)
    passed = sum(ok for _, ok, _ in judged)
    rate = passed / total
    low, high = wilson(passed, total)
    needed = math.ceil(TARGET * total)
    meals = len({r["meal"] for r in filled})
    onto = [(r, ok) for r, ok, _ in judged if r["food_already_on_plate"].strip()]
    first = [(r, ok) for r, ok, _ in judged if not r["food_already_on_plate"].strip()]
    reasons = [why for _, ok, why in judged if not ok]
    missed = sum(w.startswith("missed") for w in reasons)
    wrong = sum(w.startswith("wrong food") for w in reasons)
    dupes = sum(w.startswith("duplicate") for w in reasons)
    masses = [float(r["added_mass_g"]) for r in filled if r["added_mass_g"].strip()]
    foods = sorted({r["food_added"].strip() for r in filled})
    status = "Simulated example (not measured)" if simulated else ("Requirement met" if rate >= TARGET else "Requirement not met")

    out = [banner + "# Miqdar (مقدار) Integrated System: Food-Addition Detection and Logging Report", ""]
    out += [
        "**Document:** `" + (source.rsplit(".", 1)[0] + "_REPORT.md") + "`  ",
        "**Project:** Miqdar Smart Nutrition Scale & Mobile System (Senior Capstone)  ",
        "**Specification:** For supported food classes, the integrated system shall correctly detect and log each "
        "newly added food item with 90% event detection accuracy.  ",
        f"**Trial log:** `evaluation/addition_trials/{source}` (N = {total} additions in {meals} meals)  ",
        "**System under test:** Raspberry Pi scale (HX711 load cell, Camera Module 3) with the Miqdar app, "
        "automatic food detection on Add Meal, Gemini for food identification  ",
        f"**Status:** {status}  ",
        "",
        "---",
        "",
        "## 1. Executive Summary & Key Results",
        "",
        ("In this simulated example, " if simulated else "")
        + f"{total} food additions of at least {MIN_MASS_G:.0f} g "
        + ("are recorded" if simulated else "were made on the scale")
        + f", {len(first)} as the first food on an "
        f"empty plate and {len(onto)} on top of food already there. **{passed} of {total}** produced exactly one correct "
        f"saved entry, a success rate of **{rate * 100:.0f}%** against the **{TARGET * 100:.0f}%** requirement.",
        "",
        "| Metric | Result | Target | Status |",
        "| :--- | :---: | :---: | :---: |",
        f"| **Total additions tested** | **{total}** | >= 20 | {'Met' if total >= 20 else 'Below'} |",
        f"| **Successful detection and logging rate** | **{_pct(passed, total)}** | >= {TARGET * 100:.0f}% "
        f"({needed}/{total}) | **{'Met' if rate >= TARGET else 'Not met'}** |",
        f"| First food on an empty plate | {_pct(sum(ok for _, ok in first), len(first))} | | |",
        f"| Added onto food already on the plate | {_pct(sum(ok for _, ok in onto), len(onto))} | | |",
        f"| Missed additions (not detected) | {missed} | | |",
        f"| Wrong food saved | {wrong} | | |",
        f"| Duplicate entries | {dupes} | 0 | {'Met' if dupes == 0 else 'Not met'} |",
        f"| 95% confidence interval (Wilson) | {low * 100:.0f}% to {high * 100:.0f}% | | |",
        f"| Gemini requests used | {meals} (one per meal, at Done) | | |",
        f"| Added mass range | {min(masses):.0f} g to {max(masses):.0f} g (mean {sum(masses) / len(masses):.0f} g) | "
        f">= {MIN_MASS_G:.0f} g each | |",
        "",
        "---",
        "",
        "## 2. Methodology",
        "",
        "### 2.1 What one trial is",
        f"One trial is one **addition event**: one supported food of at least {MIN_MASS_G:.0f} g put on the plate, alone or on "
        "top of food already there. Additions were made in meals of two to four foods, with the plate zeroed empty "
        "before each meal.",
        "",
        "### 2.2 Pass and fail",
        "A trial **passes** only when all of these hold:",
        "1. **Detected:** the app recorded the addition by itself (a new \"Food N · grams\" row) with no button pressed.",
        "2. **Correct food:** after Done, the saved meal names the food that was added.",
        "3. **Logged once:** exactly one saved entry for that addition, with its added grams, not the plate's total.",
        "",
        "A missed addition, a wrong food, a duplicate entry or an entry that was never saved is a **failure**.",
        "",
        "### 2.3 Formula",
        "```",
        "Successful detection and logging rate = Successful additions / Total test additions x 100",
        f"                                      = {passed} / {total} x 100 = {rate * 100:.0f}%",
        "```",
        f"The requirement is at least {TARGET * 100:.0f}%, so at least {needed} of {total} additions must pass.",
        "",
        "### 2.4 How the system detects an addition",
        f"With Add Meal open and automatic detection on, the app polls the scale every 0.5 s. When the reading rises at least "
        f"{MIN_MASS_G:.0f} g above the last recorded food, the scale reports it as stable, and it stays within 2 g for 5 s, "
        "the scale weighs only the added grams (the new reading minus the previous one) and photographs the plate. Done "
        "sends every photo with its grams to Gemini in one request, which names each food. The meal is saved with each "
        "food listed separately with its own grams.",
        "",
        "---",
        "",
        "## 3. Results by Kind of Addition",
        "",
        "| Kind of addition | Trials | Passed | Rate |",
        "| :--- | :---: | :---: | :---: |",
        f"| First food on an empty plate | {len(first)} | {sum(ok for _, ok in first)} | "
        f"{(sum(ok for _, ok in first) / len(first) * 100 if first else 0):.0f}% |",
        f"| Added onto food already on the plate | {len(onto)} | {sum(ok for _, ok in onto)} | "
        f"{(sum(ok for _, ok in onto) / len(onto) * 100 if onto else 0):.0f}% |",
        f"| **All additions** | **{total}** | **{passed}** | **{rate * 100:.0f}%** |",
        "",
        "---",
        "",
        "## 4. Trial-by-Trial Log",
        "",
        "| Trial | Meal | Food added | Already on the plate | Added mass | Saved as | Correct entry saved once? |",
        "| :---: | :---: | :--- | :--- | :---: | :--- | :---: |",
    ]
    for r, ok, _ in judged:
        out.append(f"| {r['trial']} | {r['meal']} | {r['food_added']} | {r['food_already_on_plate'] or '(empty plate)'} | "
                   f"{float(r['added_mass_g']):.0f} g | {r['saved_as'] or '(nothing)'} | {'Pass' if ok else '**Fail**'} |")

    by_food: dict[str, list[bool]] = defaultdict(list)
    for r, ok, _ in judged:
        by_food[r["food_added"].strip()].append(ok)
    out += ["", "---", "", "## 5. Supported Foods Tested", "",
            f"{len(foods)} foods were tested. Each was added at least once.", "",
            "| Food | Trials | Passed | Rate |", "| :--- | :---: | :---: | :---: |"]
    for food, res in sorted(by_food.items()):
        out.append(f"| {food} | {len(res)} | {sum(res)} | {sum(res) / len(res) * 100:.0f}% |")

    out += ["", "---", "", "## 6. Failure Analysis", ""]
    fails = [(r, why) for r, ok, why in judged if not ok]
    if not fails:
        out.append("No trial failed.")
    else:
        out += ["| Trial | Food | Added mass | Failure | Note |", "| :---: | :--- | :---: | :--- | :--- |"]
        for r, why in fails:
            out.append(f"| {r['trial']} | {r['food_added']} | {float(r['added_mass_g']):.0f} g | {why} | {r['notes'].strip()} |")

    out += [
        "", "---", "", "## 7. Statistical Confidence", "",
        f"Twenty trials are a small sample. With {passed} of {total} passing, the 95% Wilson interval for the true rate is "
        f"**{low * 100:.0f}% to {high * 100:.0f}%**: the measured {rate * 100:.0f}% is the best estimate, and more trials "
        "would narrow the range.",
        "", "---", "", "## 8. Reproducing This Report", "",
        "Fill one row per addition in `evaluation/addition_trials/template.csv` (or a copy), then run:",
        "```bash",
        "python3 evaluation/addition_trials/score_trials.py your_trials.csv --out your_trials_REPORT.md",
        "```",
        "The setup and steps are in `docs/ADDITION_TRIALS.md`.",
    ]
    if simulated:
        out += ["", "> **SIMULATED EXAMPLE, NOT MEASURED.** Do not quote these numbers."]
    return "\n".join(out) + "\n"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("csv", type=Path)
    parser.add_argument("--out", type=Path, help="also write the report to this Markdown file")
    args = parser.parse_args()
    rows, simulated = load(args.csv)
    text = report(rows, simulated, args.csv.name)
    print(text)
    if args.out:
        args.out.write_text(text, encoding="utf-8")


if __name__ == "__main__":
    main()
