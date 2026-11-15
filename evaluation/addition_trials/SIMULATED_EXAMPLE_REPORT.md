> **SIMULATED EXAMPLE, NOT MEASURED.** These rows were invented to show the format of the report. They are not results and must never be presented as results.

# Miqdar Integrated System: Food-Addition Detection and Logging Report

**Document:** `SIMULATED_EXAMPLE_REPORT.md`  
**Project:** Miqdar Smart Nutrition Scale & Mobile System (Senior Capstone)  
**Specification:** For supported food classes, the integrated system shall correctly detect and log each newly added food item with 90% event detection accuracy.  
**Trial log:** `evaluation/addition_trials/SIMULATED_EXAMPLE.csv` (N = 20 additions in 7 meals)  
**System under test:** Raspberry Pi scale (HX711 load cell, Camera Module 3) with the Miqdar app, automatic food detection on Add Meal, Gemini for food identification  
**Status:** Simulated example (not measured)  

---

## 1. Executive Summary & Key Results

In this simulated example, 20 food additions of at least 20 g are recorded, 7 as the first food on an empty plate and 13 on top of food already there. **19 of 20** produced exactly one correct saved entry, a success rate of **95%** against the **90%** requirement.

| Metric | Result | Target | Status |
| :--- | :---: | :---: | :---: |
| **Total additions tested** | **20** | >= 20 | Met |
| **Successful detection and logging rate** | **95.0% (19/20)** | >= 90% (18/20) | **Met** |
| First food on an empty plate | 100.0% (7/7) | | |
| Added onto food already on the plate | 92.3% (12/13) | | |
| Missed additions (not detected) | 1 | | |
| Wrong food saved | 0 | | |
| Duplicate entries | 0 | 0 | Met |
| 95% confidence interval (Wilson) | 76% to 99% | | |
| Gemini requests used | 7 (one per meal, at Done) | | |
| Added mass range | 22 g to 355 g (mean 131 g) | >= 20 g each | |

---

## 2. Methodology

### 2.1 What one trial is
One trial is one **addition event**: one supported food of at least 20 g put on the plate, alone or on top of food already there. Additions were made in meals of two to four foods, with the plate zeroed empty before each meal.

### 2.2 Pass and fail
A trial **passes** only when all of these hold:
1. **Detected:** the app recorded the addition by itself (a new "Food N · grams" row) with no button pressed.
2. **Correct food:** after Done, the saved meal names the food that was added.
3. **Logged once:** exactly one saved entry for that addition, with its added grams, not the plate's total.

A missed addition, a wrong food, a duplicate entry or an entry that was never saved is a **failure**.

### 2.3 Formula
```
Successful detection and logging rate = Successful additions / Total test additions x 100
                                      = 19 / 20 x 100 = 95%
```
The requirement is at least 90%, so at least 18 of 20 additions must pass.

### 2.4 How the system detects an addition
With Add Meal open and automatic detection on, the app polls the scale every 0.5 s. When the reading rises at least 20 g above the last recorded food, the scale reports it as stable, and it stays within 2 g for 5 s, the scale weighs only the added grams (the new reading minus the previous one) and photographs the plate. Done sends every photo with its grams to Gemini in one request, which names each food. The meal is saved with each food listed separately with its own grams.

---

## 3. Results by Kind of Addition

| Kind of addition | Trials | Passed | Rate |
| :--- | :---: | :---: | :---: |
| First food on an empty plate | 7 | 7 | 100% |
| Added onto food already on the plate | 13 | 12 | 92% |
| **All additions** | **20** | **19** | **95%** |

---

## 4. Trial-by-Trial Log

| Trial | Meal | Food added | Already on the plate | Added mass | Saved as | Correct entry saved once? |
| :---: | :---: | :--- | :--- | :---: | :--- | :---: |
| 1 | 1 | Rice | (empty plate) | 182 g | Rice | Pass |
| 2 | 1 | Chicken | Rice | 64 g | Chicken | Pass |
| 3 | 1 | Salad | Rice + Chicken | 41 g | Garden salad | Pass |
| 4 | 2 | Jareesh | (empty plate) | 215 g | Jareesh | Pass |
| 5 | 2 | Dates | Jareesh | 45 g | Sukari dates | Pass |
| 6 | 2 | Laban | Jareesh + Dates | 240 g | Laban | Pass |
| 7 | 3 | Tamees bread | (empty plate) | 88 g | Tamees bread | Pass |
| 8 | 3 | Hummus | Tamees bread | 96 g | Hummus | Pass |
| 9 | 3 | Boiled egg | Tamees bread + Hummus | 52 g | Boiled egg | Pass |
| 10 | 4 | Kabsa rice | (empty plate) | 250 g | Kabsa rice | Pass |
| 11 | 4 | Grilled chicken | Kabsa rice | 110 g | Grilled chicken | Pass |
| 12 | 4 | Cucumber | Kabsa rice + Grilled chicken | 23 g | Cucumber | Pass |
| 13 | 5 | Falafel | (empty plate) | 120 g | Falafel | Pass |
| 14 | 5 | Salad | Falafel | 22 g | (nothing) | **Fail** |
| 15 | 5 | Tahini | Falafel | 30 g | Tahini | Pass |
| 16 | 6 | Pepsi can | (empty plate) | 355 g | Pepsi | Pass |
| 17 | 6 | 7-Up can | Pepsi can | 355 g | 7-Up | Pass |
| 18 | 7 | Saleeg | (empty plate) | 230 g | Saleeg | Pass |
| 19 | 7 | Chicken | Saleeg | 75 g | Chicken | Pass |
| 20 | 7 | Dates | Saleeg + Chicken | 30 g | Sukari dates | Pass |

---

## 5. Supported Foods Tested

17 foods were tested. Each was added at least once.

| Food | Trials | Passed | Rate |
| :--- | :---: | :---: | :---: |
| 7-Up can | 1 | 1 | 100% |
| Boiled egg | 1 | 1 | 100% |
| Chicken | 2 | 2 | 100% |
| Cucumber | 1 | 1 | 100% |
| Dates | 2 | 2 | 100% |
| Falafel | 1 | 1 | 100% |
| Grilled chicken | 1 | 1 | 100% |
| Hummus | 1 | 1 | 100% |
| Jareesh | 1 | 1 | 100% |
| Kabsa rice | 1 | 1 | 100% |
| Laban | 1 | 1 | 100% |
| Pepsi can | 1 | 1 | 100% |
| Rice | 1 | 1 | 100% |
| Salad | 2 | 1 | 50% |
| Saleeg | 1 | 1 | 100% |
| Tahini | 1 | 1 | 100% |
| Tamees bread | 1 | 1 | 100% |

---

## 6. Failure Analysis

| Trial | Food | Added mass | Failure | Note |
| :---: | :--- | :---: | :--- | :--- |
| 14 | Salad | 22 g | missed: not detected | example failure: a hand stayed on the plate so the weight never rested for 5 s |

---

## 7. Statistical Confidence

Twenty trials are a small sample. With 19 of 20 passing, the 95% Wilson interval for the true rate is **76% to 99%**: the measured 95% is the best estimate, and more trials would narrow the range.

---

## 8. Reproducing This Report

The trial log is `evaluation/addition_trials/addition_trials.csv`, one row per addition. The report is made from it with:
```bash
python3 evaluation/addition_trials/score_trials.py evaluation/addition_trials/addition_trials.csv \
  --out evaluation/addition_trials/ADDITION_TRIALS_REPORT.md
```
The setup and steps are in `docs/ADDITION_TRIALS.md`.

> **SIMULATED EXAMPLE, NOT MEASURED.** Do not quote these numbers.
