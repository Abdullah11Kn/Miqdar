# Miqdar: source material for Report 3

Use this file, together with the picture supplied by Abdullah, as the source for Report 3. It records the software and
integration work done after Report 2, as far as the project's code history and notes show it.

## Rules for writing the report

1. **Period:** 12 October to 5 November 2026. Report 2 (the Second Design Notebook) covered 13 September to 11 October 2026.
2. **Leave out the visual redesign.** The app's new design system is held for the report after this one, so do not describe
   its look: its colors, fonts, buttons, floating bars or screen layouts. Section 4 describes what the app does, not how it
   looks. Do not use a screenshot of the current app unless the team has confirmed it fits this rule.
3. **Only claim what is recorded here.** Section 7 says which requirements are unproven. Do not present any of them as met.
4. **Do not quote the 400-sample evaluation** (F1 scores and the like, in `evaluation/`). Its data is placeholder, not a real test.
5. **Add what this file cannot know.** See section 10: meetings, coach feedback and the mechanical and electrical work.

## 1. The project

Miqdar (مقدار, "amount") is a smart kitchen scale with a phone app, for Saudi and Gulf food. The user puts food on the plate,
the scale weighs and photographs it, and the app shows the food's calories and nutrients and saves it to a diary.

Team M015, Senior Design II, Term 261, King Fahd University of Petroleum and Minerals.

**Hardware:** Raspberry Pi 4B, HX711 load cell (5 kg capacity), Camera Module 3, 3.5" 640×480 touchscreen.
**Software:** Python on the Pi (scale driver, touchscreen and REST API), Flutter for the phone app, Google Gemini for food recognition.

## 2. Where Report 2 ended

- The application was reported complete. The electrical circuits were complete for the current prototype.
- AI testing and response-time troubleshooting were continuing.
- The design planned to recognize a food, then look its nutrition up in a database, with a backend holding the cloud credential.
- Event IDs, stage timing and proof that each meal saves once were proposed but not verified.
- The stated next priority was evidence: a log linking image, weight, AI result, response time and saved record.

## 3. Timeline

| Date (2026) | Work |
|---|---|
| 21–25 Oct | Full-stack integration guide and front-end requirements; app expanded with a food catalog, 8-nutrient display, charts, and Arabic and English |
| 31 Oct | Real scale integrated: load cell and camera drivers, touchscreen program, REST API, and app connection to the scale |
| 1 Nov | Live weight in the app; capture synced both ways; Gemini moved to the app; analysis speed and accuracy improved; core app flow rebuilt around the real scale |
| 2 Nov | Screens that only pretended to work removed; start at boot added; public tunnel turned off by default; documents corrected; first test of the rebuilt app on the real scale |
| 4 Nov | Feature plan agreed, then built: body profile and goals, mixed plates, logging away from the scale, quick re-logging, body weight log, meal reminders; code review findings fixed |
| 5 Nov | Pi updated and checked; app prepared for a real iPhone and Android; a hand-named plate fixed |

## 4. Work completed

### 4.1 Scale and Raspberry Pi

- Connected the HX711 load cell and camera through new drivers, with a calibration tool. Calibrated with a 200 g reference mass on 20 October.
- Built the touchscreen program and a REST API on port 8080 that the app polls every 500 ms for the live weight.
- Added zeroing, a 5 kg overload warning, and refusal of a capture on an empty plate (under 5 g).
- A capture now refuses a weight that never settles. Before this fix, a hand on the food silently produced wrong calories.
- Settling ignores the highest and lowest tenth of readings and waits up to 8 s, so a brief wobble does not fail it.
- Fixed a fault that disabled image processing on the Pi, which was sending full-size photos to the app.
- Added a sensor fault state, so a load cell problem is reported rather than shown as a weight.
- Added start at boot, desktop launchers and scripts to control the Pi from a Mac over Wi-Fi.
- Added a simulated scale, so the app can be tested without the hardware.

### 4.2 Food recognition and nutrition

- **Main design change:** Gemini now analyzes every food, in the app. The Pi only weighs and photographs. Ingredients vary between home-cooked dishes, so one stored record per dish was judged unreliable.
- **Calculation:** calories = Gemini's value per 100 g of edible food × edible fraction × measured grams. Gemini estimates the first two, and the app does the arithmetic, so the measured weight always counts.
- **Edible fraction** accounts for peel, rind, shells and bones. Half a pomegranate went from 202 to about 102 kcal.
- The prompt describes the real camera view, reads packaged food labels, and is given local dish names. Without those names, Gemini read jareesh as an Iranian dish at 95% confidence.
- Answers whose calories disagree with their macronutrients are rejected.
- Photos are sent at a smaller size (768 px). Models are tried in order with a time limit each (8 s per model, 35 s in total), so a slow or overloaded one is skipped.
- Results are labelled as estimates, show Gemini's confidence and assumptions, and can be corrected by the user, which re-analyzes the same photo.

### 4.3 Phone app functions

- Three ways to add a meal: from the scale, from a search of 38 foods, or by hand.
- Review before saving: photo, name, calories, macronutrients, source of the values, portion adjustment, alternatives and added sides.
- Diary with search and filters, meal detail, editing, Log Again and deletion with Undo. Meal photos are kept.
- Insights over 7, 30 and 90 days, and CSV export copied to the clipboard.
- Nutrient goals and over-goal notices. Arabic and English, with right-to-left layout, and light and dark themes.
- All data stays on the phone in a local SQLite database, with migrations up to version 6. There are no accounts, by decision.
- A nutrient nobody knows shows "Unknown", never 0.

### 4.4 Features added on 4 November

- **Body profile and calculated goal:** the user answers a short profile, and the app calculates a daily goal with safety limits. Goals change only if the user accepts. Users under 18, pregnant or breastfeeding are not given a calculated goal.
- **Mixed plates:** foods are added to one plate step by step, each with its own weight and photo, with Add Next Food, Undo, Finish and Cancel on both the app and the touchscreen. Gemini gets one request for the whole plate, and it saves as one meal with a row per food.
- **Recovery when Gemini fails:** the photos and weights are kept, and the user can ask again or name the foods themselves. Saving waits until every food has a name.
- **Logging away from the scale:** take a photo with the phone, or describe the meal by text or voice. These amounts are marked as estimated, not weighed.
- **Quick re-logging:** recent foods can be repeated from Search with their saved values, using no Gemini request.
- **Body weight log:** typed entries with a chart. A 2 kg change offers an updated goal.
- **Meal reminders:** optional local notifications, off by default.

### 4.5 Reliability and honesty

- Removed sign-in, password reset, pairing, sync and account deletion, which did nothing real.
- Removed a made-up battery reading (there is no battery sensor) and sample meals from real totals. Sample data now exists only in a demo that saves nothing.
- Added a real scale connection test, Delete All My Data, and privacy text stating that food photos go to Google and that the free plan may use them.
- The app tells the user when a scale restart lost an unfinished plate, and asks what to do when a plate gets lighter.
- A plate reads as an estimate if any of its foods is an estimate.

### 4.6 Testing and documentation

- 97 automated app tests and 43 automated Python tests, all passing at the latest run on 5 November. They run against simulated hardware, not the real scale.
- End-to-end tests of the capture flow and the mixed plate flow, run on an iOS simulator with a simulated scale and the real Gemini service.
- A real database upgrade test, from version 3.
- Current documents for the API, hardware and technical reference, checked against the code. Outdated documents were archived.

## 5. How this differs from Report 2's plan

| Report 2 | Now | Why |
|---|---|---|
| Recognize, then look up a nutrition database | Gemini estimates nutrition directly; the database path remains as an option on the Pi | Ingredients vary between home-cooked dishes |
| Backend holds the cloud credential | The key is on the phone side, in local test builds only | Simpler flow; the Pi needs no key. **Risk:** a key can be extracted from a build, so this must change before any public release |
| Proposed event IDs linking one capture to one result | Implemented for scale captures; the app ignores an event it has already seen | As proposed |
| Automatic detection of each added item | The user presses Add Next Food | Decided by Abdullah on 4 November, in place of automatic detection. **Check this against the ≥90% detection requirement** |
| Nutrition values from one database entry give identical results | Values are estimates and can vary: the same sample photos gave 448 kcal and 403 kcal in two runs | A direct result of using Gemini |

## 6. Problems found and solved

| Problem | Solution |
|---|---|
| Gemini misidentified local dishes | Local dish names are given in the prompt |
| A preview model took up to 26 s on a photo stable models answer in 2–5 s | Stable models first, with a time limit per model |
| The main model overloaded and the free quota ran out during testing | Fallback models, a specific message, and search or manual entry stay available |
| Calories counted inedible parts | Edible fraction added |
| A moving weight was used silently | The capture is refused and the user is asked to retry |
| Arabic never really worked: the layout flipped but the text stayed English | Registered the locale and translated the app |
| Fake screens and values misrepresented the system | Removed, as in section 4.5 |
| A test run wiped saved meals on the simulator | Integration tests now run only on a throwaway simulator |

## 7. Status of the requirements

Targets are from the requirements carried forward in Report 2. **None has a formal acceptance test yet.**

| Requirement | Status | Evidence so far |
|---|---|---|
| Food recognition ≥80% | Not shown | No valid test set. Known example: one jareesh photo was read as both jareesh and saleeg |
| End-to-end response ≤12 s | Not shown | No timing log. Early real-scale capture about 21 s, later faster; Gemini usually 2–5 s; one description request took 15 s under load |
| Added-item logging ≥90% for ≥20 g | Not shown | Works step by step on the simulated scale. Not run on the real scale, and detection is now a button press |
| Calorie error ≤±15% | Not shown | Informal only; see section 8 |
| At least 90 days of history | Partly shown | The app has a 90-day view. An automated test queries 90 days on the older server path |
| Cloud AI and secure REST | Partly shown | Gemini works. The API has an optional token, but on the local network it uses plain HTTP, and the public tunnel has no password unless the token is set |

## 8. Measured results, with their limits

| Result | Limit |
|---|---|
| Calorie error fell from 12.5% to 2.8% after improving the prompt | About 10 test photos (a commit message says 25, which is wrong). Informal, not an acceptance result |
| Half a pomegranate: 202 → about 102 kcal | One example showing the edible-fraction effect |
| Real scale, 243 g pomegranate, about 21 s | One early capture on the older path, and it got faster later |
| Simulated scale with real Gemini: Saleeg, 240 g, 336 kcal | Proves the flow works, not accuracy. The photo was a sample of jareesh |
| Simulated scale with real Gemini: Chicken Kabsa 200 g + Jareesh 120 g, 448 kcal | Sample photos, not one real plate building up |
| Real scale connection on 2 and 5 November | Connects, reads 0 g, zeroes, sensor OK, no throttling, and refuses an empty plate. No food was on the plate |

## 9. Remaining work

1. **Real food on the real scale with the current app.** This is the most important test, including real mixed plates, and it was not done at the time of writing.
2. **Formal tests with logs:** recognition, response time and calorie error, each on real captures.
3. **Prove start at boot.** It failed once for an unknown reason, and needs a power cycle and a look at its log.
4. **Real iPhone build,** to test voice, phone camera and delivered reminders. The last attempt stopped because the phone's Developer Mode was off.
5. **Android build.** The setup is in place, but it has never been built.
6. **Gemini billing:** the project is on the free plan, limited to about 20 requests a day per model. The team decided to stay on it for now.
7. **Move the Gemini key behind a server** before any public release.

## 10. Not in this file: the team must add

The sources here are the code history and project notes, so they only show software and integration work, and they do not say who did what.

- Meetings after 11 October: dates, attendance and decisions.
- Coach feedback.
- Mechanical and electrical work after 11 October, including the enclosure, camera arm, power supply, and thermal and overload checks.
- Which team member did which task.
