# Miqdar (مقدار): context for the ICS poster

Background for an AI tool that writes and designs a senior-project poster. It covers the software (ICS)
side of Miqdar: what the team set out to build, how it was engineered over 16 weeks, and what it does
today. Two photos come with it: the scale itself, and the phone showing a captured meal with its calories.

## In one line

Miqdar is a smart kitchen scale and phone app that turns a plate of food into a weighed calorie and
nutrition log in about three seconds. It weighs the food instead of guessing, and it is built for Saudi
and Gulf cuisine.

## The problem we solved

Calorie apps fail where it matters most: the portion. They guess grams from a photo or make the user type
them, and that guess is the biggest source of error. They also barely know kabsa, jareesh, saleeg, dates or
laban, and they treat people with diabetes, who need carbs and sugar per meal, like everyone else.

## Our approach: measure, then understand

The scale measures what a camera cannot: the true weight. The AI does what a scale cannot: recognise the
dish and give its nutrition per 100 g. The app combines the two.

**Calories = calories per 100 g of edible part × edible fraction × measured grams ÷ 100**

The edible fraction removes peel, bones and shells, so a banana or chicken on the bone is counted as it is
eaten.

## System architecture

A three-part system engineered end to end:

1. **The scale (Raspberry Pi 4B):** a load cell with HX711 and a camera. Custom Python software filters
   the signal, waits until the weight is stable, takes the photo, and serves everything through a REST API
   on the local network. A touchscreen gives the scale its own Capture, Zero, Save and Cancel.
2. **The phone app (Flutter):** reads the live weight twice a second, receives the photo the moment it is
   taken, and runs the analysis.
3. **The AI (Google Gemini):** a prompt engineered for a fixed camera over a white plate and for Gulf home
   cooking, returning the dish, its nutrition and its edible fraction.

Place food → weighed and photographed → recognised → calories on screen → saved to the diary.

## Engineering highlights

- **About 3 seconds from photo to result.** Profiling found the delay in the network, not the AI. Resizing
  photos on the device, opening the AI connection ahead of time and running barcode checks in parallel cut
  the time from about 30 s to under 3.2 s on an iPhone.
- **Never blocked.** Three Gemini models in a fallback chain, strict time limits, a calorie plausibility
  check, and manual entry when the AI is unavailable.
- **Mixed plates, one food at a time.** Put rice, then chicken: the app notices each new food (20 g or
  more, still for 5 s), weighs it by the difference, and names the whole meal in one AI request.
- **Every capture counted once.** Event IDs between scale and phone stop a retry or a second phone from
  logging the same meal twice.
- **Built to be trusted.** AI values are labelled as estimates, barcodes are checked against Open Food
  Facts, and the diary stays on the phone.

## Beyond calories

- **Diabetes mode:** carbohydrates first, a suggested carb amount per meal, a red warning before eating when
  a meal would pass a safe limit (WHO free sugar guidance), and a blood sugar log beside meals.
- **Built for Saudi life:** full Arabic and English, a Ramadan mode with Iftar and Suhoor, and Gulf dishes
  recognised first.
- **For the doctor:** a PDF report the app writes from the user's own meals.
- **Personal goals** calculated from a body profile with medical safety limits.

## Specifications and how they are addressed

| Specification | How Miqdar meets it |
|---|---|
| End-to-end response within 12 s | About 3 s measured on an iPhone, photo to result |
| Log each added food of 20 g or more | Automatic detection of each addition, weighed by difference |
| Food recognition for local cuisine | Prompt tuned for Gulf dishes, barcode and label reading as second sources |
| Accurate calories | True weight from the scale, edible fraction, plausibility check |
| At least 90 days of history | Local diary with daily, weekly and long-term views |
| Cloud AI over a secure REST interface | Gemini over HTTPS; scale API with optional token protection |

## The work in numbers

- 16 weeks of development
- About 24,000 lines of Flutter app code and 2,400 lines of Python on the scale
- About 280 automated tests, plus end-to-end tests on a simulated scale
- 44 tracked features and tasks, 125+ commits
- 2 languages, light and dark themes, iOS and Android from one codebase

## Technology

Python · Raspberry Pi OS · HX711 · Picamera2 · Flutter / Dart · SQLite · Google Gemini API · Open Food
Facts API · Apple Health

## The photos

- **The scale:** the Miqdar kitchen scale with its plate, camera and touchscreen.
- **The phone:** the app's result screen, showing the food photo taken by the scale and its calories.
