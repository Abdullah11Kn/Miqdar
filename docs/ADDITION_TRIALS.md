# Food-addition trials: how to measure the 90% requirement

The integrated specification says: *for supported food classes, the integrated system shall correctly detect and log
each newly added food item with 90% event detection accuracy.* This page says how to measure that on the real scale and
how to show the result. **No trials have been run yet** (2026-11-15).

## What counts

- **One event** is one addition: one supported food of at least 20 g put on the plate, alone or on top of food already
  there.
- **Pass:** the app records it by itself (a "Food N · grams" row appears without a button), and after Done the saved
  meal lists it **once**, with the **correct food** and the **added grams**.
- **Fail:** missed (no row), wrong food, saved twice, or not saved.
- **Requirement:** at least 90%, so at least **18 of 20**.

This is a success rate per addition. It is not Gemini's "% sure" badge, and not the accuracy of the weight, which is a
separate specification.

## Before starting

1. Phone and scale on the same hotspot; only **one phone** open on the scale, or a capture can be saved twice.
2. Add Meal open, **Detect each food automatically** on.
3. Empty plate on the scale, then **Zero**.
4. Decide the supported foods and write them down first, for example rice, chicken, jareesh, dates, laban, tamees,
   hummus, salad, a soft-drink can. Test only those.

## Running a meal (2 to 4 additions)

1. Put the first food on and take your hand away. After 5 still seconds "Food 1" appears.
2. Add the next food (20 g or more), hand away, wait for the next row. Repeat.
3. Tap **Done**, check Review, **Save**.
4. Open the meal in the Diary and fill one row per addition in the trial log.
5. Take the food off (or Zero) before the next meal.

Twenty additions in about seven meals use about **seven Gemini requests**, because detection and weighing do not use
Gemini; only Done does, once per meal.

## Recording and showing the result

- `evaluation/addition_trials/addition_trials.csv`: the empty log for the real trials, one row per addition.
- `evaluation/addition_trials/SIMULATED_EXAMPLE.csv`: invented rows that show the format and how a failure is
  written. **Not measured. Never present it as a result.**
- `evaluation/addition_trials/score_trials.py`: turns a log into the results table, the rate, results per food, the failed trials and a
  95% confidence interval:

```bash
python3 evaluation/addition_trials/score_trials.py evaluation/addition_trials/addition_trials.csv --out evaluation/addition_trials/ADDITION_TRIALS_REPORT.md
```

The report is laid out like `evaluation/EVALUATION_400_REPORT.md`: header, key results, method, results by kind of
addition, the trial log, foods tested, failures and confidence. `evaluation/addition_trials/SIMULATED_EXAMPLE_REPORT.md`
shows it, generated from the simulated example. Any file whose name or first line says SIMULATED is labelled as simulated
on every output.

Twenty trials are a small sample: 19 of 20 measured means the true rate is very likely somewhere between about 76% and
99%. Say so when presenting; it shows the measurement is understood, not weakened.
