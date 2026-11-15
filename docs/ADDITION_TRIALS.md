# Food addition trials: how to run, record and present them

The integrated specification: *for supported food classes, the integrated system shall correctly detect and log each
newly added food item with 90% event detection accuracy.*

This guide says how to measure that on the real scale. **No real trial has been run yet** (2026-11-15). The files
below are a blank sheet, an invented example to show the format, and a script that turns any sheet into the results.

| File | What it is |
|---|---|
| `evaluation/addition_trials/template.csv` | The blank sheet for the real trials: 20 rows in 7 meals |
| `evaluation/addition_trials/SIMULATED_EXAMPLE.csv` | **Invented rows, not measured.** Shows how a filled sheet and a failure look. Never present it as results |
| `evaluation/addition_trials/report.py` | Makes the results table, the rate, and breakdowns by food and kind of addition |

## What 90% means

One **event** is one addition: putting one supported food of at least 20 g on the plate. Each event passes or fails.

| Outcome | Counts as |
|---|---|
| Detected, the right food saved, saved exactly once, with its added grams | Pass |
| Nothing recorded (missed) | Fail |
| The wrong food saved | Fail |
| Saved twice | Fail |

Rate = passes ÷ additions × 100. At least **18 of 20** passes meets 90%. This is not Gemini's "% sure" on a photo,
and not the scale's weighing accuracy, which is a different specification.

## Supported foods

State the list before testing, and test only from it. A good list for Miqdar: rice (plain or kabsa), chicken (grilled
or cooked), jareesh, saleeg, dates, tamees bread, hummus, falafel, boiled egg, salad, cucumber, laban, canned drinks.

## Setting up

1. Phone and scale on the same hotspot. **Only one phone** with the app open, so no capture is saved twice.
2. Add Meal open, on Scale, with **Detect each food automatically** on.
3. Empty plate on the scale, tap **Zero**.

## One meal of trials

1. Put the first food on. Hands off. Wait for "Food 1 · N g" (about 5 seconds). That is one trial.
2. Leave it there. Add the next food (20 g or more). Hands off. Wait for "Food 2 · N g". The next trial.
3. A third food the same way, if the meal has one.
4. Tap **Done**, check Review, tap **Save**. Then open the meal in the Diary.
5. Write each food's row in the sheet (below), then take everything off the plate, or tap Zero, for the next meal.

20 additions in 7 meals are 7 Gemini requests, one per meal. The free plan allows about 20 a day per model, so the
trials fit, with room for a live demonstration.

## Recording each trial

| Column | What to write |
|---|---|
| `trial`, `meal` | Numbers, already filled in the blank sheet |
| `food_added` | The food you put on |
| `food_already_on_plate` | What was there before; empty for the first food |
| `added_mass_g` | The grams shown on its "Food N" row |
| `detected` | `yes` if its "Food N" row appeared by itself |
| `saved_as` | The name in the saved meal in the Diary |
| `correct_food` | `yes` if that name is the food you added (a close name such as "Sukari dates" for dates is right) |
| `entries_saved` | How many times it appears in the saved meal: 1 is right |
| `notes` | Anything unusual, especially for a failure |

Then:

```bash
python3 evaluation/addition_trials/report.py evaluation/addition_trials/my_trials.csv
```

## Presenting it

Show the table the script prints, the rate line, and the breakdown "first food" against "added with food already on
the plate", because the second is what the specification is about. Explain every failure in one line. Then repeat two
or three additions live: rice, wait for Food 1, add chicken, wait for Food 2, Done, Save, open the meal in the Diary.

Words that fit: *"One event is adding one supported food of at least 20 grams. A trial passes only when it produces
exactly one saved entry with the correct food and its added weight. We ran 20 additions over 7 meals, including
additions with food already on the plate, and N passed, so the rate is N × 5 %."*

Only say this with a sheet from real trials. The simulated example shows the format and nothing else.
