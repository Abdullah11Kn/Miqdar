"""Turns a sheet of food-addition trials into the results table and the success rate.

    python3 evaluation/addition_trials/report.py evaluation/addition_trials/SIMULATED_EXAMPLE.csv
    python3 evaluation/addition_trials/report.py my_real_trials.csv > results.md

The specification: for supported foods, each newly added food (20 g or more) is detected and logged with at least
90% success. A trial passes only when the addition was detected, the right food was saved, and it was saved exactly
once. A missed addition, a wrong food or a duplicate is a failure.

A sheet whose first line starts with "# SIMULATED" is an invented example. Every line of its report says so.
"""
import csv
import sys
from collections import defaultdict
from pathlib import Path

TARGET = 0.90
MIN_GRAMS = 20.0
REQUIRED = ["trial", "meal", "food_added", "added_mass_g", "detected", "correct_food", "entries_saved"]


def yes(value: str) -> bool:
    return value.strip().lower() in ("yes", "y", "true", "1", "pass")


def load(path: Path):
    lines = path.read_text(encoding="utf-8").splitlines()
    simulated = bool(lines) and lines[0].lstrip().upper().startswith("# SIMULATED")
    rows = list(csv.DictReader(line for line in lines if not line.lstrip().startswith("#")))
    missing = [c for c in REQUIRED if rows and c not in rows[0]]
    if missing:
        sys.exit(f"Missing columns: {', '.join(missing)}")
    filled = [r for r in rows if r["food_added"].strip() and r["added_mass_g"].strip()]
    return simulated, filled


def passed(row) -> bool:
    entries = int(row["entries_saved"] or 0)
    return yes(row["detected"]) and yes(row["correct_food"]) and entries == 1


def failure_reason(row) -> str:
    if not yes(row["detected"]):
        return "missed (not detected)"
    entries = int(row["entries_saved"] or 0)
    if entries > 1:
        return f"duplicate ({entries} entries)"
    if entries == 0:
        return "detected but not saved"
    return "wrong food"


def report(path: Path) -> str:
    simulated, rows = load(path)
    if not rows:
        return "No filled trials in this sheet yet."
    banner = "**SIMULATED EXAMPLE - NOT MEASURED. These rows were invented to show the format.**\n\n" if simulated else ""
    out = [banner + "# Food addition trials: detection and logging", ""]
    small = [r for r in rows if float(r["added_mass_g"]) < MIN_GRAMS]
    if small:
        out.append(f"Note: {len(small)} trial(s) below {MIN_GRAMS:.0f} g do not count toward the specification and are left out.")
        rows = [r for r in rows if float(r["added_mass_g"]) >= MIN_GRAMS]
    ok = sum(passed(r) for r in rows)
    rate = ok / len(rows)
    meals = len({r["meal"] for r in rows})
    out += [
        "| Trial | Food added | Already on the plate | Added mass | Correct entry saved once? |",
        "|---|---|---|---|---|",
    ]
    for r in rows:
        on_plate = r.get("food_already_on_plate", "").strip() or "(empty plate)"
        verdict = "Pass" if passed(r) else f"Fail: {failure_reason(r)}"
        out.append(f"| {r['trial']} | {r['food_added']} | {on_plate} | {float(r['added_mass_g']):.0f} g | {verdict} |")
    out += [
        "",
        f"**Successful detection and logging rate = {ok} / {len(rows)} x 100 = {rate * 100:.0f}%** "
        f"(target {TARGET * 100:.0f}%: {'met' if rate >= TARGET else 'NOT met'}; "
        f"at least {int(-(-TARGET * len(rows) // 1))} of {len(rows)} needed).",
        "",
        f"{len(rows)} additions in {meals} meals, so {meals} Gemini requests (one per meal, at Done).",
        "",
    ]
    first = [r for r in rows if not r.get("food_already_on_plate", "").strip()]
    added = [r for r in rows if r.get("food_already_on_plate", "").strip()]
    out += ["| Kind of addition | Passed |", "|---|---|"]
    for label, group in (("First food on an empty plate", first), ("Added with food already on the plate", added)):
        if group:
            out.append(f"| {label} | {sum(passed(r) for r in group)} / {len(group)} |")
    by_food = defaultdict(list)
    for r in rows:
        by_food[r["food_added"].strip()].append(passed(r))
    out += ["", "| Food | Passed |", "|---|---|"]
    for food, results in sorted(by_food.items()):
        out.append(f"| {food} | {sum(results)} / {len(results)} |")
    fails = [r for r in rows if not passed(r)]
    if fails:
        out += ["", "Failures:"]
        for r in fails:
            note = f" ({r['notes'].strip()})" if r.get("notes", "").strip() else ""
            out.append(f"- Trial {r['trial']}, {r['food_added']}, {float(r['added_mass_g']):.0f} g: {failure_reason(r)}{note}")
    if simulated:
        out += ["", "**SIMULATED EXAMPLE - NOT MEASURED.**"]
    return "\n".join(out)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    print(report(Path(sys.argv[1])))
