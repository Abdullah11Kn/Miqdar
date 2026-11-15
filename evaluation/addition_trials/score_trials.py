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


def report(rows: list[dict[str, str]], simulated: bool, source: str) -> str:
    filled = [r for r in rows if r["food_added"].strip()]
    banner = ("> **SIMULATED EXAMPLE, NOT MEASURED.** These rows were invented to show the format. "
              "They are not results and must never be presented as results.\n\n" if simulated else "")
    if not filled:
        return banner + f"`{source}` has no filled trials yet.\n"
    lines = [banner + f"Source: `{source}`\n",
             "| Trial | Food added | Already on the plate | Added mass | Saved as | Correct entry saved once? |",
             "|---:|---|---|---:|---|---|"]
    passed = 0
    failures = []
    on_plate = [0, 0]
    for r in filled:
        ok, why = judge(r)
        passed += ok
        if r["food_already_on_plate"].strip():
            on_plate[0] += ok
            on_plate[1] += 1
        if not ok:
            failures.append((r["trial"], r["food_added"], why, r["notes"].strip()))
        lines.append(f"| {r['trial']} | {r['food_added']} | {r['food_already_on_plate'] or '(empty plate)'} | "
                     f"{float(r['added_mass_g']):.0f} g | {r['saved_as'] or '(nothing)'} | {'Pass' if ok else 'Fail'} |")
    total = len(filled)
    rate = passed / total
    low, high = wilson(passed, total)
    needed = math.ceil(TARGET * total)
    verdict = "meets" if rate >= TARGET else "does not meet"
    lines += [
        "",
        f"**Successful detection and logging rate = {passed} / {total} × 100 = {rate * 100:.0f}%**, "
        f"which {verdict} the 90% requirement (at least {needed} of {total}).",
        "",
        f"- Additions made with food already on the plate: {on_plate[0]} of {on_plate[1]} passed.",
        f"- 95% confidence interval for the true rate: {low * 100:.0f}% to {high * 100:.0f}% "
        f"(Wilson). With only {total} trials, the true rate could be this far from the measured one.",
    ]
    if failures:
        lines += ["", "Failed trials:"]
        lines += [f"- Trial {t} ({food}): {why}." + (f" {note}" if note else "") for t, food, why, note in failures]
    if simulated:
        lines += ["", "> **SIMULATED EXAMPLE, NOT MEASURED.**"]
    return "\n".join(lines) + "\n"


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
