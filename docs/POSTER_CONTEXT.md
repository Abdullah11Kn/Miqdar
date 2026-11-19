# Miqdar (مقدار): context for the ICS poster

This is background for an AI tool that writes and lays out a senior-project poster. It describes the
software (ICS) work only. Use it as source facts; write the poster's own wording from it.

## The project in one line

Miqdar is a smart kitchen scale with a phone app that weighs a meal, photographs it, and estimates its
calories and nutrients, built for Saudi and Gulf food.

## The problem

- Calorie apps guess the portion from a photo or ask the user to type it. The portion is the largest
  source of error.
- Most apps know little about Saudi and Gulf dishes (kabsa, jareesh, saleeg, dates, laban).
- People with diabetes need carbohydrate and sugar numbers per meal, not only calories.

## The idea

Measure the weight instead of guessing it, and let AI do only what a scale cannot: name the food and give
its nutrition per 100 g.

**Calories = (calories per 100 g of edible part) × (edible fraction) × (measured grams) ÷ 100**

The edible fraction removes peel, bones and shells, so a banana or chicken on the bone is not overcounted.

## How it works (the flow)

1. The user puts food on the plate of the scale.
2. The Raspberry Pi weighs it until the reading is stable, then takes a photo.
3. The phone app reads the live weight twice a second and downloads the photo over Wi-Fi.
4. The app sends the photo and the weight to Google Gemini, which names the food and returns nutrition
   per 100 g and the edible fraction.
5. The app multiplies by the measured grams and shows the result. The user reviews and saves it to a diary
   kept on the phone.

The scale holds no AI key and does no AI work; it only weighs and photographs.

## The software built (ICS contribution)

**On the scale (Raspberry Pi 4B, Python):**
- Reads the HX711 load cell, calibrated with a 185 g reference weight; zeroing; a stability check that
  ignores short wobbles.
- Takes the photo with Camera Module 3 only once the weight is stable.
- A REST API on the local network (live weight, capture, zero, photo, multi-food plates).
- A touchscreen interface (3.5") with Capture, Zero, Save and Cancel, matching the app's design.
- Set up to start by itself when the scale is switched on.

**The phone app (Flutter, iOS and Android, English and Arabic, light and dark):**
- Add Meal: live weight, the photo appears at once, then the food name and calories.
- Mixed plates: each added food is weighed separately by the weight difference, and the whole plate is
  named in one AI request. The app can detect each newly added food (20 g or more, at rest for 5 s)
  by itself.
- Gemini prompt design, a fallback chain of three Gemini models, time limits, and a plausibility check on
  calories. Every AI value is labelled as an estimate.
- Barcode reading (phone camera or the scale's photo) with Open Food Facts, and nutrition-label reading.
- Logging away from the scale: phone photo, or describing the meal in text or voice.
- Diary, daily goals calculated from a body profile, insights, body weight log, water, meal reminders.
- Diabetes mode: carbohydrates first, a suggested carb amount per meal, red warnings before eating for
  free sugar, calories and carbs, and a blood sugar log.
- Ramadan mode (Iftar, Suhoor), weighing leftovers, and a doctor's PDF report.
- A local SQLite database on the phone; no accounts, the diary stays on the device.

## Results that were actually measured

- The real scale connects to the app over Wi-Fi and shows the true weight; zeroing works; a capture of an
  empty plate is refused.
- Real food on the real scale, for example a 34 g biscuit estimated at 146 kcal.
- Speed: after optimisation (smaller photos sent to the AI, connections opened in advance), the time from
  photo to result on an iPhone went from about 26 to 32 s down to about 3 s (2.8 s and 3.1 s measured).
- About 280 automated unit tests for the app, plus end-to-end tests on a simulated scale.

## Rules for the poster

- No accuracy percentage has been measured yet. Do not invent one. If a result is needed, use the
  measured speed above, or say "accuracy trials in progress".
- Do not use the 400-sample benchmark or any "simulated" trial numbers; they are placeholders.
- Calories from Gemini are estimates, never "verified" or "exact".
- Food photos are sent to Google Gemini for analysis; do not claim the AI runs on the device.
- Never show a battery level or any number the system does not measure.

## Photos supplied with the poster

- The scale: the Raspberry Pi kitchen scale with its plate, camera and touchscreen.
- The phone: the app's result screen with the captured food photo and its calorie output.

## Suggested poster sections

Problem · Idea · System overview (scale → phone → Gemini → diary) · Software built · Results · Future work
(accuracy trials on real meals, user accounts, more Gulf dishes).

## Technology

Python, Raspberry Pi OS, HX711, Picamera2, Flutter / Dart, SQLite, Google Gemini API, Open Food Facts API,
Apple Health.
