# Miqdar: shared notes for every agent

Every agent and every new chat works from this file, so nothing is lost between chats.
**Any change you make gets written here.** The next agent knows only what this file and the code say.

## Every chat: three steps

1. **Before working:** read this whole file, then run `git status`, `git pull` and `git log --oneline -5`.
   If the code and these notes disagree, trust the code and correct the notes.
2. **While working:** follow the rules below. Do not redo or reverse a listed decision unless Abdullah asks.
3. **Before ending your reply:** if you changed anything, add a log entry and update "Current state" and
   "Open decisions". Commit this file together with the change. If you stop halfway, say what is unfinished.

**Writing a log entry:** newest on top, under [Change log](#change-log), in this form:

```
### YYYY-MM-DD: short title (commit abc1234)
- Changed: what is different now, and why.
- Tested: what you actually ran and the result.
- Not tested / risks: what nobody has checked, what could break.
- Next: what the next agent should do, if anything.
```

Be honest: write failures and guesses as failures and guesses. Never put keys or passwords here; this
repository is **public**. Log user requests and decisions too, not only code. If two agents edit at once,
keep both entries.

## The project

Miqdar (مقدار) is Abdullah's senior project: a smart kitchen scale with a Flutter app, for Saudi and Gulf food.
Raspberry Pi 4B, HX711 load cell, Camera Module 3, 3.5" touchscreen.

**Default flow:** food on the plate → the Pi (`app.py`) weighs and photographs it, and only that → the app polls
`/scale/live` every 500 ms and downloads the photo → the app sends it to Gemini using a key held on the app side →
calories = per-100 g edible value × edible fraction × measured grams → the user reviews and saves to a diary on the
phone. The Pi needs no Gemini key. `--analyze-on-scale` or `--server` is the old database path.

**About Abdullah:** explain in plain language, with the result first. He tests on the iOS simulator on his Mac.

## Current state

*Update this section whenever it stops being true. Last updated 2026-11-05.*

- **Branch:** `feature/scale-live-flow` holds all current work, and the Pi is on it. `main` is well behind and
  `origin/usb` is an older copy. Do not merge to `main` until Abdullah says so.
- **App:** follows the black and white version of the Miqdar design system (`docs/DESIGN.md`), set in Thmanyah, in English and Arabic, light and dark. There are no accounts, by decision. A fresh clone needs `mobile/assets/fonts/install_thmanyah.sh` before it builds.
- **Real scale, new app, verified 2026-11-02:** connects at `foodscale.local`, shows the true reading (0 g, sensor ok),
  Zero works, and an empty-plate capture is refused.
- **Real food on the real scale, 2026-11-05:** Abdullah captured real food with the current flow (a 34 g biscuit, 146 kcal, by his photos). The Pi's log shows 8 results, 3 to 17 s from photo to result. No accuracy was measured.
- **Still not verified on the real scale:**
  1. Formal accuracy and timing tests, and mixed plates on real food. These are the most important next tests.
  2. Starting at boot: on the 2026-11-05 00:04 boot the scale was not running 8 minutes later, cause unknown. The same autostart mechanism ran a test entry correctly. `start_all.sh` now logs to `/tmp/miqdar_start.log`. Power-cycle it and read that log; rebooting over SSH needs a password.
- **Pi:** tunnel off by default, but someone started it with the Internet icon on 2026-11-05 at 02:36 and it was still running at the last check. The scale's Wi-Fi address works.
- **Pi code:** pulled to the commit of the 2026-11-05 entry "Save and Cancel on the touchscreen", with Thmanyah installed. The scale must be restarted to load it, and the phone needs the matching app build for Save and Cancel. `git pull` works there again since the history rewrite. The earlier calibration is backed up in `~/miqdar-backup/` on the Pi.
- **USB-C networking:** Abdullah remembers it working. On 2026-11-04 the Mac got no reply at 192.168.7.1 and no address from the Pi, even though the Pi's `miqdar-usb` connection reads as active. Use the `iphone A` hotspot, which works.
- **Gemini:** free plan. Flash models allow about 20 requests a day per model. On 2026-11-02 the main model was
  overloaded and the last fallback was out of quota.
- **Next work (after the code review, all fixed):** every ticket from GitHub issue #1 (#2 to #13) is built. Still open because they need hardware: #4 and #5 (real scale), #10 and #13 (real iPhone).
- **Agent skills setup:** done. See Agent skills below.
- **Planned next:** spec #14 (Weigh What's Left, diabetes mode, doctor's report, Ramadan mode), not yet split into tickets or built.

## Where things live

```
AGENTS.md                 This file
Local tool files         Not on GitHub, ignored by git: the skills in .agents/skills/ and their lock file, and the file that makes the coding tool load these notes. Reinstall them with npx skills if they are ever missing
README.md                 Project overview
app.py                    Runs on the Pi: scale screen, REST API on :8080, capture
hardware.py, scale.py     HX711 and camera drivers; calibration tool
scale_calibration.json    Calibration values, tracked in git
start_all.sh              What boot and the Pi icons run: fullscreen scale; --tunnel adds the public address
start_scale_app.sh        Start the scale app (--headless --mock simulates it on a Mac)
start_cloudflare_tunnel.sh, start_server.sh
install_pi_desktop.sh     Pi setup, desktop icons, start at boot. Run again after every git pull on the Pi
enable_usb_ssh_pi.sh      Pi: USB-C network (see Current state)
connect_pi.sh             Mac: terminal on the Pi
run_simulator.sh          Mac: run the app with the key from .env, on the real scale by default
run_iphone.sh             Mac: install a test build on his own iPhone; never distribute it, the key is inside
run_checks.sh             Rebuilds the database, then runs all tests
mobile/lib/
  app_controller.dart     App state; capture flow; saving
  services/               gemini_service (prompt, model order), api_service (scale), alert_service, reminder_service
  data/                   local_database (SQLite v6, meal photos, meal_items, body_weights), food_catalog
  models/nutrition.dart   Data models
  models/body_profile.dart  Body profile and the goal calculation
  theme.dart              All colors (context.mq) and text styles (MiqdarType)
  miqdar_icons.dart       Icons from mobile/assets/fonts, generated; see the README there
mobile/assets/fonts/thmanyah/  The text fonts. Not in git, by licence; install_thmanyah.sh beside it puts them there; install_thmanyah_pi.sh copies them to the Pi for its touchscreen
  l10n/strings.dart       English and Arabic text, s.tr(en, ar), s.date(...)
  ui/                     Screens; ui/widgets/charts_and_gauges.dart for shared widgets
mobile/test/              Unit tests
mobile/integration_test/  scale_flow_test, mixed_plate_flow_test and scale_bar_capture_test: end-to-end flows on a simulator
backend/                  Python service and tests (old path, /recommendations, goals)
database/                 Food database, seeds and build scripts
evaluation/               Benchmark tools and test_recognition.py. The 400-sample data is placeholder
docs/                     Current documents, listed in docs/README.md
docs/archive/             Old documents, kept for history. Do not follow them as instructions
```

**Do not move or rename** `app.py`, `hardware.py`, `scale.py`, `scale_calibration.json`, `requirements.txt` or the
root `.sh` scripts. The Pi's desktop icon and installed setup use those exact paths, and the scripts and tests refer
to each other.

## Commands

```bash
./run_simulator.sh                                        # the app, connected to the real scale
./run_simulator.sh http://127.0.0.1:8080                  # the app, connected to a simulated scale on this Mac
./start_scale_app.sh --headless --mock                    # simulated scale; add --auto-capture for scale_flow_test
cd mobile && flutter analyze && flutter test              # app checks
PYTHONPATH=backend .venv/bin/python -m unittest discover -s backend/tests    # Python tests
ssh miqdar-pi                                             # the Pi (user foodscale, repo ~/Miqdar), over Wi-Fi
```

On the Pi after new code: `git pull origin feature/scale-live-flow && ./install_pi_desktop.sh`.

## Rules

**Safety**
- Keep the Gemini key only in `.env`, which git ignores. GitHub rejects pushes containing keys.
- The public tunnel exposes the camera and API, so it stays off unless needed (`./start_all.sh --tunnel`). `MIQDAR_API_TOKEN` can protect them.
- Commit and push finished work to the feature branch. Never to `main` without asking.
- Never credit any AI tool or agent on GitHub: no `Co-Authored-By` trailers, no "generated with" lines, and no such wording in commits, issues, PRs or labels. Abdullah's rule, and it overrides any tool default.
- Do not use a password you found in the documents. If something needs one, leave it and ask.
- Never commit, upload or cut down the Thmanyah font files. Their licence allows embedding them in the built app, but forbids hosting and changing them, and this repository is public.

**Protecting his data**
- Run integration tests on a throwaway simulator (`xcrun simctl create`), never on his iPhone 16 Pro simulator.
  `flutter test` reinstalls the app and wipes that simulator's saved meals. This has already happened twice.
- Running the simulated scale changes the tracked `database/miqdar_nutrition.db`. Restore it with
  `git checkout -- database/miqdar_nutrition.db` before committing, unless the change is intended.
- Restart the simulated scale between test runs, or the last capture reopens as a new review.

**App honesty**
- Do not add a screen that looks like sign-in, pairing or sync unless it really does that. No fake numbers
  (there is no battery sensor, so never show a battery level).
- The default diary holds only real meals. Sample meals exist only in the demo (`account.isDemo`), which must never
  write to the database.
- Gemini values are estimates and must be labelled as such, never "verified".
- Privacy & Data states that food photos go to Google and that the free plan may use them. Keep this true.
- Do not present the 400-sample evaluation as real results.

**Code**
- All user-facing text goes through `s.tr(en, ar)`, and dates through `s.date(...)`. Check Arabic and dark mode.
- Follow `docs/DESIGN.md`. Colors come from `context.mq` and text from `MiqdarType`, never values written in a screen.
- A database column change needs a version bump and a migration in `local_database.dart`.
- No screen-code jargon in the interface (S36, PRD-07, ms timings).
- New documents go in `docs/`, or `docs/archive/` once outdated, and in the `docs/README.md` list. Do not add loose `.md` files to the root. Keep one document per topic.
- Saying "works" means you ran it. A passing test on the simulated scale does not prove the real scale works.
- Gemini can misname food (it read one Jareesh photo as both Jareesh and Saleeg). Tests must not require an exact dish name.

**Showing work to Abdullah**
- Opening the app's icon on the simulator runs the last build, not the latest code. After app changes, run `./run_simulator.sh` on his simulator yourself (it keeps his data) and confirm with a screenshot, instead of telling him it is done.

**Pi hardware**
- `pkill -f "app.py"` over SSH kills your own shell. Use `pkill -f "[a]pp.py"`.
- A Mac IDE blocked by macOS Local Network privacy shows `No route to host`. That is not a hotspot problem.
- The Pi's terminal runs all its windows in one process. Killing `x-terminal-emulator` stops the scale too.
- A plain virtualenv cannot import `lgpio` and `picamera2`; it must use `--system-site-packages`.

## Agent skills

### Issue tracker

GitHub Issues in `Abdullah11Kn/Miqdar`, through the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

The default labels, except that `ready-for-agent` is `ready-to-build` here. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one `GLOSSARY.md` and `docs/adr/` at the root, created only when needed. See `docs/agents/domain.md`.

## Decisions Abdullah made

- Gemini analyzes every food. No database lookup or repeated stored foods for the scale flow, because ingredients change.
- The Gemini key lives on the app side, not on the Pi.
- Add Meal shows the live weight and a Capture button. The photo appears immediately with loading, then the food name and calories.
- Agents have full freedom on UX and AI choices, as long as nothing gets blocked. He wants the best result, not literal obedience.
- The 400-sample benchmark is fake placeholder data: ignore it.
- 2026-11-02: he tried the orange brand redesign (commit e6c80e7) on his simulator, did not like it, and asked for the previous green design back. Do not bring back the orange look unless he asks. The earlier request to improve the design is still open: ask him what he wants before another redesign.
- 2026-11-02: earlier requirements no longer bind the project, including `docs/archive/FRONTEND_REQUIREMENTS_V3.md`. No accounts or sign-in; the diary stays on the phone. "You are one of us, do the best for the project": act on your own judgment and report plainly.
- 2026-11-04: he made a design system and asked for it to be applied ("do it"). It replaces the green design as the app's look. It keeps a green, in a deeper shade, with orange as the attention color.
- 2026-11-04: new feature plan, in issue #1. Priority is daily use, with the most effort on what will be demonstrated. Build one at a time: body profile and goal; mixed plates; logging away from the scale (phone camera, describe by text or voice, as a secondary option); quick re-logging from Search; body weight log; meal reminders.
- 2026-11-04: the profile is required for every user, but skippable in test builds while he tests. Rice with chicken added as one plate is one meal. Adding the next food uses a button on both screens, not automatic detection. Short wobbles of the weight are accepted.
- 2026-11-04: features that do not use the scale need no hardware testing. He will come back to agents when he is ready for a real-meal accuracy test.
- 2026-11-05: he asked for the black and white version of his design system to be implemented as the app's UI and UX, in the Thmanyah fonts. It replaces the deep green look of 2026-11-04.

- 2026-11-05: on the scale, a single food goes from Capture straight to one Analyzing screen with Cancel, then to a result with Save. No "Photo sent" screen and no Capture on the result. Add Next Food is a separate flow and keeps its own screens.

## Open decisions

Waiting for Abdullah. Do not settle these alone.

1. **Public repository contains the Pi hotspot password** in `docs/HARDWARE.md`, and possibly the PDFs in
   `docs/archive/handover/`. Deleting it from current files does not remove it from git history. Change the password on
   the devices (Wi-Fi and Pi login), or make the repository private. Going private also needs login on the Pi for `git pull`.
2. **Enable Gemini billing.** On 2026-11-04 he chose to stay on the free plan for now and pay later if other people will test the app.
3. **Merge to `main`.** Only when he says.
4. **The Profile tab's Arabic name.** The design system says حسابي ("my account"). The app says ملفي, changed by another session on 2026-11-05 because there are no accounts. The new design left it as ملفي.

Settled 2026-11-02: boot start and tunnel off (done); Change Food and Add Side stay, because they are the way to log food
when Gemini is down; USB-C is dropped in favor of Wi-Fi.

## Change log

Newest first. Older history: `git log` and `docs/CHANGELOG_1.1.md`.

### 2026-11-07: Planned four new features; spec published as issue #14
- Decided: through `/grill-me`, Abdullah chose Weigh What's Left (container method only), diabetes mode, a doctor's PDF report and Ramadan mode, in that order. Cook-once recipe weighing was rejected. The confidence display stays as it is until he removes it himself. The report summary is worked out by the app, with no AI. Ramadan mode is a Settings switch the app suggests near Ramadan, with Iftar, Suhoor and Snack, a noon-to-noon day, and no times. He asked for the carb numbers to be researched. He ran `/to-spec` with five questions unanswered (the numbers, when no number is offered, no suhoor and iftar split, per-meal number separate from the daily goal, and what "nothing" referred to); the spec takes the recommended answers and says so.
- Changed: added `docs/research/diabetes-carb-guidance.md`, listed in `docs/README.md`. Published issue #14. No app or Pi code changed.
- Tested: nothing to run. The research was checked against primary sources where they could be reached; the Ramadan carb split and ADCES material could not be.
- Not tested / risks: no current guideline gives a fixed carb number per meal; the 45 g and 60 g defaults are common teaching, offered as a choice. The PDF and Hijri calendar packages are not yet checked to build.
- Next: `/to-tickets` on issue #14, then build Weigh What's Left first.

### 2026-11-05: Save and Cancel on the touchscreen; full technical record for Report 3 (commits 692e811 and the next one)
- Decided: from photos of his real capture, Abdullah said Capture on the waiting and result screens made no sense and "Photo sent" was useless, for a single food only. He then asked for the Report 3 file to be a full technical record, not a short summary, still leaving out the artifact's design.
- Changed: a single food goes from Capture to one Analyzing screen, with Cancel once the phone has the photo, then to a result with Review on Phone and Save to Diary, then Saved. Save and Cancel are `save_request` and `cancel_request` in `/scale/live`, answered through new `POST /scale/capture/outcome`; the touchscreen says Saved only after the phone answers, and says so if it does not within 10 s. Added the simulation route `/scale/simulate/save` and `scale_save_test`. A failed save answers `failed`. Rewrote `docs/REPORT_3_INPUT.md`.
- Careful: `mobile/build` is a link to `/tmp/miqdar_mobile_build`, so after the Mac restarts Flutter fails with `PathNotFoundException` until that folder is recreated (`mkdir -p`; `run_checks.sh` does it). The notes' "768 px" is only the old server path; the Pi sends 1280×960. The new Report 3 file was checked against the code.
- Tested: 103 app tests; 50 of 50 Python tests; `flutter analyze`; on a throwaway simulator with the simulated scale and real Gemini: `scale_save_test` and `scale_flow_test` after the last change, `scale_bar_capture_test` and `mixed_plate_flow_test` before Cancel was added. The screens were captured from the real Pi display in a temporary window.
- Not tested / risks: no one has tapped Save or Cancel on the physical touchscreen, or used them against the real scale. Cancel is tested only at unit level, because Gemini usually answers before a test could press it. Cancel cannot stop the settling and photo stage, so it appears once the phone has the photo. Undo on the phone after a save from the scale does not update the scale. The running scale was NOT restarted, because a phone was connected.
- Next: Abdullah restarts the scale and tries Save and Cancel with food on the plate.

### 2026-11-05: Wrote the source material for Report 3
- Decided: Abdullah asked for a file his colleague can give an AI, with a picture, to write Report 3. It covers the work since Report 2 and leaves out the design from his design system artifact, which is held for the next report.
- Changed: added `docs/REPORT_3_INPUT.md`. No app or Pi code changed.
- Careful: Report 2 was taken to be his Second Design Notebook, so the period starts on 12 October. The design system's earlier version, applied on 4 November, is left out too, because it came from the same artifact. Features built on top of it are described by function only.
- Tested: facts checked against the code, git log, these notes and the notebook. Nothing to run.
- Not tested / risks: the file cannot cover meetings, coach feedback, or mechanical and electrical work after 11 October; the team must add those. It should be corrected if food tests happen before the report is written.

### 2026-11-05: Scale touchscreen matches the app's design (commit aeae659)
- Decided: Abdullah asked for the "balance screen" to be made compatible with the new design. Taken to mean the Pi's touchscreen.
- Changed: `draw_screen` in `app.py` uses the design system's dark tokens, Thmanyah, pill buttons, a white main action, plain weight with locked digits, and sentence-style labels. Phone results now read "Gemini estimate", and a missing value reads Unknown, not 0. The exit screen now says plainly that closing stops the phone connecting. Actions and flow are unchanged. New `install_thmanyah_pi.sh` copies the fonts over SSH, because the licence keeps them out of git; without them the screen falls back to DejaVu Sans.
- Tested: 43 of 43 Python tests, including a new one for the labels; all screen states looked at as pictures rendered on the Mac. On the Pi: code at aeae659, fonts copied, and eight screens drew without error in a hidden Tk window using Thmanyah.
- Not tested / risks: NOT yet seen on the physical screen, because the running scale still has the old code loaded. It was not restarted: someone had just started it with the Internet icon, and a restart changes the public address. Touch taps on the new buttons are not tested. Arabic food names are not shaped on this screen, as before. Boot start and real food are still open.
- Next: restart the scale from a desktop icon, then check the look and the buttons on the device. The public tunnel was running at the time; it exposes the camera and API, so turn it off when not needed.

### 2026-11-05: Applied the black and white design system, in Thmanyah (commit 707a8ef)
- Decided: Abdullah asked for his design system artifact to become the app's UI and UX, with the Thmanyah fonts. He had put the zips in `mobile/assets/fonts`.
- Changed: new tokens and type in `theme.dart`; white and black grounds, ink pill main action, every button a pill. A floating scale bar with its own Capture sits over a capsule of four tabs and a round green Add Meal, replacing the five-tab bar, the green Home card and the capture strip. The bar hides on Add Meal. Bare rows for meals, settings, Goals, Privacy and Search. Profile header without the gradient. The source label on Review is no longer hidden in a collapsed section. Danger buttons are text. The icon font now keeps weights 300 to 400. `LockedNumber` holds live digits to one width, because Thmanyah's digits are proportional with no tabular feature. `FilterChip` became `ChoiceChip` on Meal Ideas, because it ignored the card's fill. New `scale_bar_capture_test`. `docs/DESIGN.md` rewritten, `docs/APP_SCREENS.md` corrected where screens moved.
- Careful: the licence inside the font files forbids hosting and changing them, and the repository is public, so the fonts are ignored by git and are not subset. Abdullah did not rule on this; it follows the licence text.
- Tested: `flutter analyze`; 97 unit tests; 42 of 42 Python tests; on a throwaway simulator with the simulated scale and real Gemini: `scale_bar_capture_test`, `scale_flow_test` (Saleeg, 240 g, 336 kcal), `mixed_plate_flow_test`. A temporary tour with a fake scale ran all four language and theme modes with no layout errors; most English light and Arabic dark screens looked at, a sample of the other two. His simulator rebuilt, Home confirmed by screenshot, goals kept, scale connected at 0 g.
- Not tested / risks: real food on the real scale, still the top test. Not looked at after the change: Failure sheet, Analyzing, Edit Meal, Choose Meal Photo, food portion sheet, plate item sheet, body weight sheet, Export, Notices with content, the wide sidebar, Android. The tests used Gemini's free daily quota, about three requests. Tests showed two main screens overlap for a moment after onboarding; the count settles at one, and the tests now require that.
- Next: Abdullah to judge the look on his simulator and settle open decision 4. If this app is ever built elsewhere, that Mac needs the zips from font.thmanyah.com.

### 2026-11-05: Prepared the app for a real iPhone and Android
- Decided: Abdullah asked for everything not yet done to be finished while he tests food. Another session has a large uncommitted redesign in this folder, so this work was tested in a separate git worktree and only its own files were committed.
- Changed: added the Local Network message and local networking setting a real iPhone needs. Added `run_iphone.sh`. Added Android permissions, notification receivers and desugaring for voice and reminders. Recent foods in Search show their source. The Arabic Profile tab is ملفي, because there are no accounts.
- Tested: 96 unit tests and `flutter analyze` in the clean worktree.
- Also fixed: a plate named by hand kept its first food's name; it now lists all its foods, and Gemini's name for a plate stays. Found by the tour.
- Tested later: 97 unit tests. A temporary tour with a fake scale and fake Gemini passed, with these looked at: Enter by Hand, the lighter-plate dialog and the restart card in English and Arabic; the Arabic plate food sheet and name dialog; the pregnancy refusal; Recent in Search.
- Not tested / risks: Android has never been built here, because this Mac has no Android SDK, so that setup follows the packages' instructions only. `run_iphone.sh` reached the phone and stopped because Developer Mode is off, so no real-iPhone build exists. Something shut down a throwaway simulator during testing; separate sessions sharing this folder can collide on `mobile/build` and on simulators, so use a git worktree.
- Next: Abdullah turns on Developer Mode, then `./run_iphone.sh`, then real-iPhone tests for #10 and #13; power-cycle and food tests for #4 and #5.

### 2026-11-05: Checked the Pi update on the real scale
- Decided: Abdullah asked for the Pi update and hardware steps. Another session had already updated the Pi, so it was not repeated. A separate session has uncommitted design work in this folder, so only this file was committed.
- Tested: on the real scale: code at 3139f8a, no local changes, calibration unchanged, sensor ok, no throttling, tunnel not running. `/scale/live` has the plate and boot fields, and Add Next Food on an empty plate is refused with `EMPTY_SCALE`, leaving no plate open. It also reached the Pi on a second Wi-Fi network, at 192.168.1.164.
- Not tested / risks: no food has been on the plate. Boot start is still unproven: the Pi booted at 00:07 and the scale started at 00:21, which was the other session's manual start, and `/tmp/miqdar_start.log` does not exist yet. The empty plate reads about 1.5 g, so it should be zeroed before weighing.
- Next: Abdullah power-cycles the Pi, then the food tests.

### 2026-11-05: Updated the Pi; boot start not proven (commit 3139f8a)
- Decided: Abdullah asked for the Pi to be controlled and updated, and the real-scale steps done.
- Changed: Pi moved to the rewritten history and new code, installer run, calibration unchanged and backed up. `start_all.sh` logs its output to `/tmp/miqdar_start.log`. Someone had tapped the Internet icon, so the public tunnel was running; it was stopped when the scale restarted without it.
- Tested: over the hotspot: the new code answers on the real scale at `foodscale.local`, with plate and boot fields, 0 g, sensor ok, no throttling. A test entry ran through `lxsession-xdg-autostart`.
- Not tested / risks: food on the real plate, mixed plates, and wobble limits. Boot start failed once, cause unknown. A clean reboot over SSH was refused for lack of a password.
- Next: Abdullah power-cycles the Pi, then read the log and run the food tests. #4 and #5 stay open until then.

### 2026-11-04: Fixed what the code review found
- Decided: no reply was needed from Abdullah. Both reviews covered all the feature work.
- Changed: a plate no longer takes its labels from its first food, so it cannot read as verified while any food is a Gemini estimate. Plate foods can be entered by hand. The app says when a scale restart lost a plate, using a new `boot_id` from the Pi. A lighter plate now asks Undo Last Food or Weigh Again. A profile weight change joins the weight log, and reaching a target still offers a goal. A new user who leaves during the profile stays a new user, so an under-18 user cannot keep the default goal that way. Repeats keep saved values, and estimates stay estimates. Photos are told apart by a new `step_id`. The touchscreen lists every food's grams. Added a real upgrade test from database v3, using `sqflite_common_ffi` for tests only.
- Tested: `flutter analyze`; 96 unit tests; 42 of 42 Python tests; `mixed_plate_flow_test` on a throwaway simulator with real Gemini. The upgrade test passed before any fix, so upgrades were already safe. The same sample photos gave 448 kcal in one run and 403 in another, so a plate's estimate can move by about 10% between runs. New dialogs and cards were checked by unit tests or not at all, not by eye.
- Not tested / risks: the Pi changes are not on the Pi. Left alone on purpose: a plate is stored in both `plateItems` and `additionalItems`, `MiqdarController` keeps growing, and reminder settings are JSON in `settings` rather than a table. All are design debt, not faults.

### 2026-11-04: Checked the untested screens; fixed Unknown values, Arabic units and the 90-day test
- Changed: a plate with unnamed foods now shows Unknown instead of 0 for its total and macros. The Home card uses the plate's name. Arabic units on the new screens now match the app (غ and كغ). `test_at_least_90_days_are_queryable` creates its own dated meals, so it no longer ages.
- Tested: `flutter analyze`; 84 unit tests; 39 of 39 Python tests; a temporary tour with a fake scale and fake Gemini on a throwaway simulator, looking at Add Meal with a plate, the Failure sheet, Review with unnamed and named foods, Meal Detail and Edit Meal in English dark, Arabic light and Arabic dark.
- Not tested / risks: the sheets opened during the tour stayed in the language they opened in, so the Arabic text of the plate item sheet and name dialog was not seen. Still not on the real scale or a real iPhone.

### 2026-11-04: Removed every mention of the coding tool from GitHub
- Decided: Abdullah asked for this ("rewrite and remove") and ran the force-push script himself, because the permission system blocked it for an agent.
- Changed: rewrote `feature/scale-live-flow`, `usb` and `fix/scale-app-photo-live-weight`: credit lines removed, one commit's author changed to him, tool files removed from all history and now ignored by git but kept on his Mac, tool names in documents replaced. `main` and `feature/frontend-redesign-v3` had none, so they did not change. Commit IDs in this log and in issue comments were updated, so older IDs elsewhere point to nothing.
- Tested: no matches for the names in any message, author or file on any branch on GitHub, and the contributor list shows only him.
- Not tested / risks: GitHub can still serve old commits by their direct link until it cleans them up, which GitHub Support can speed up. A backup with the old history is in `~/Documents/miqdar-before-history-rewrite/` on his Mac, not on GitHub. The Pi has not been updated.

### 2026-11-04: Finished the agent skills setup
- Changed: Abdullah asked to finish `/setup-matt-pocock-skills`. Added `docs/agents/` for GitHub Issues, labels and domain documents, and the labels `needs-triage`, `needs-info` and `ready-for-human`. No app or Pi code changed.
- Careful: the skill says to edit the tool file that points here, but that file is not on GitHub, so the section is in this file.
- Tested: labels listed from GitHub. No skill was run with the new files.

### 2026-11-04: Quick re-logging, body weight log and meal reminders (tickets #11, #12, #13)
- Changed: Search shows up to five recent foods, reusing saved values with no Gemini request. Insights has a body weight card with a chart and an entry list; entries update the profile weight, and at 2 kg from the weight behind the goal it offers new goals, which change only if accepted. Database v6 adds `body_weights`. Profile has Meal Reminders, off by default, with local notifications that ask permission only when turned on. Packages added: `flutter_local_notifications`, `timezone`, `flutter_timezone`.
- Tested: `flutter analyze`; 82 unit tests; `scale_flow_test` and earlier `mixed_plate_flow_test` on a throwaway simulator; a temporary tour with recent foods, the weight card and the permission prompt looked at. 38 of 39 Python tests pass; `test_at_least_90_days_are_queryable` fails because its seeded data aged, which is not from this work and affects only the old server path.
- Not tested / risks: no reminder has actually been delivered, so #13 stays open for a real iPhone. Android needs extra setup in its manifest for scheduled notifications, which was not done. Quick re-logging repeats a food at its old weight, labelled as entered by hand.
- Next: Abdullah to try the app. Then real-scale tests for #4 and #5 and real-iPhone tests for #10 and #13.

### 2026-11-04: Logging away from the scale (tickets #8, #9, #10)
- Changed: Take a Photo and No Time to Weigh? on Add Meal, and Describe It Instead on the Failure sheet. Gemini estimates food and amount, marked as estimated. Microphone button via `speech_to_text`, which only fills the field. Requests that estimate an amount get 20 s per model and 50 s in all, because a real one took 15 s under load. Added the `mic` icon by rebuilding the font.
- Tested: `flutter analyze`; 70 unit tests; a temporary tour on a throwaway simulator with real Gemini ("half a plate of chicken kabsa and a small salad" gave Chicken Kabsa, 450 g, 631 kcal, estimated, which seems high); Gemini overload really happened during the test, and the failure message showed correctly. Sheet looked at in English light and Arabic dark.
- Not tested / risks: VOICE HAS NOT RUN. It builds, but needs a real iPhone in both languages, so #10 stays open. The camera was not used, because a simulator has none. No accuracy is measured for estimates.
- Next: tickets #11 onward.

### 2026-11-04: Mixed plates on the phone, with recovery when Gemini fails (tickets #6, #7)
- Changed: Add Next Food, Finish, Undo Last Food and Cancel Plate on Add Meal. One Gemini request at Finish with every photo and each food's grams. Review shows the total and a row per food, which can be renamed by typing, searched, reweighed (labelled as entered by hand) or removed. Saved as one meal; database v5 adds `meal_items`, so sides are now kept too. Log Again restores all foods. If Gemini fails, the photos and grams stay, with Ask Gemini Again or Name the Foods Myself, and saving waits until every food has a name. Only the last photo is kept with the saved meal; step photos live in memory until saved.
- Tested: `flutter analyze`; 67 unit tests; new `mixed_plate_flow_test` on a throwaway simulator with the simulated scale and real Gemini (Chicken Kabsa 200 g + Jareesh 120 g, 448 kcal, saved and read back from the database). Add Meal and Review looked at in English light.
- Not tested / risks: NOT on the real scale, and the simulated photos are separate pictures, so comparing real photos of one plate building up is unproven. That is the main accuracy risk. Arabic and dark on these screens not looked at. Failure sheet and naming tested by unit tests only, not by eye. Upgrading to v5 not checked at the time of this entry.
- Next: tickets #8 onward.

### 2026-11-04: Scale side of mixed plates and short wobbles (tickets #4, #5, still open)
- Changed: settling ignores the highest and lowest tenth of samples and waits up to 8 s, so a brief wobble passes. New plate session on the Pi with add, finish, undo, cancel and a photo per step (`docs/API.md`), and Add Next Food, Undo, Finish and Cancel on the touchscreen. Zero, Capture and automatic capture wait while a plate is open.
- Tested: 26 scale tests pass on simulated hardware; the plate touchscreen layout looked at as a rendered picture, not on the device.
- Not tested / risks: NOT run on the real scale, which did not answer at `foodscale.local` at the time, so the Pi has no new code yet. The wobble limits are guesses until then. An unrelated old test, `test_at_least_90_days_are_queryable`, fails because its seeded data aged to 87 days.
- Next: ticket #6. Close #4 and #5 after a real-scale run.

### 2026-11-04: Body profile and calculated goal (tickets #2, #3)
- Changed: every real user answers a required Body Profile (after Get Started, or on next launch after updating). The app calculates a daily goal with safety limits, and goals change only if the user accepts. Skip exists only outside release builds. Editable from Profile. Database v4. Privacy & Data and Delete All My Data cover it. Also made the rule that GitHub never credits the tool or any agent; the `ready-for-agent` label became `ready-to-build`.
- Tested: `flutter analyze`; 51 unit tests; a temporary tour on a throwaway simulator through the form, errors, result, Home, restart on the real database, under-18 refusal and Delete All, with screenshots in English light and Arabic dark looked at; his simulator updated from database v3 to v4 with goals kept, and the profile appeared (screenshot).
- Not tested / risks: the pregnancy refusal only in unit tests; English dark and Arabic light result screens captured but not looked at; the Android build; `scale_flow_test` was changed to tap Skip but not rerun. A person's age comes from a birth year, so it can be off by one. 27 older commits still carry a co-author line; rewriting them needs a force push and his approval.
- Next: ticket #4.

### 2026-11-04: Agreed the next features and published the spec (issue #1)
- Decided: through `/grill-me`, Abdullah chose the plan listed under Decisions. He re-ran `/to-spec` without finishing `/setup-matt-pocock-skills`, which was taken as approval of GitHub Issues, the three test points and one spec.
- Changed: published the spec as GitHub issue #1, public, labelled `ready-for-agent`, a label created for it. No app or Pi code changed.
- Tested: nothing to run. The facts in the spec came from reading the code, and the plan itself is untested.
- Not tested / risks: one Gemini request per plate is a reasoned choice, not measured. The macro split, the 2 kg goal-update offer and the target weight checks are agent defaults he did not ask for. Real food capture on the real scale is still unverified.
- Next: build the body profile. Finish `/setup-matt-pocock-skills` if he wants `docs/agents/`.

### 2026-11-04: Applied the design system to the whole app
- Changed: new colors with a new dark mode, type, shapes and shared components across every screen, as a theme in `theme.dart` plus the components in `charts_and_gauges.dart`. Icons are now Material Symbols Rounded, cut to a 17 KB font in `mobile/assets/fonts`. New bottom bar. One main button per screen; Capture becomes secondary once a photo is chosen. Scale fault and simulated states now show on the Home card. Review tiles show Unknown for missing macros. Removed unused GlassCard and aiming overlay. No logic, API or database change. `docs/DESIGN.md` rewritten, `docs/APP_SCREENS.md` updated.
- Also fixed: Insights had two Arabic names; some small English text on Arabic screens; the Choose Meal Photo sheet overflowed on a phone, found while testing.
- Tested: `flutter analyze`; 35 unit tests; `scale_flow_test` on a throwaway simulator with a simulated scale and real Gemini (Saleeg, 240 g, 336 kcal, saved); a temporary screenshot tour of the main screens in all four language and theme modes, sheets in two, with no layout errors, and most of the screenshots looked at; not-connected states in English light; his simulator rebuilt and Home confirmed by screenshot, his data kept.
- Not tested / risks: the REAL scale with this design, which read "not connected" from his simulator at that moment; real food capture is still the top test. Not looked at after the change: the Failure sheet, Analyzing screen, Edit Meal, Name and Export sheets, dialogs, low-confidence and Gemini source badge colors, the wide sidebar, Android.
- Next: Abdullah to judge the look. Weak points the design system did not address are listed in `docs/APP_SCREENS.md` section 13, such as the phone camera being hard to reach.

### 2026-11-04: Wrote the current screens down for a redesign
- Decided: Abdullah wants to redesign the app with a design tool, and asked for a description of the current design, screens and buttons to give it. He has not said yet what direction he wants.
- Changed: added `docs/APP_SCREENS.md` and listed it in `docs/README.md`. No app or Pi code changed.
- Tested: written from reading every file in `mobile/lib/ui`, `theme.dart` and `strings.dart`. Only Home (empty day) was compared with a screenshot; other screens were not looked at.
- Next: when the app's screens change, update that document too. Any design he brings back still has to follow the App honesty rules.

### 2026-11-02: Added the frontend-design skill
- Changed: Abdullah pasted the `skills-lock.json` entry for `frontend-design` from `a public skills repo`, so it was installed in `.agents/skills/`. No app or Pi code changed.
- Careful: the installed hash starts `89496d5d`, and his pasted entry had `4eabc661`. Probably the skill was updated since his copy, but that was not checked. The skill pushes bold, new visual choices; the decision above still stands, so ask him what he wants before another redesign.
- Tested: the skill file was read and has instructions only. It has not been run.

### 2026-11-02: Added all the mattpocock skills
- Changed: Abdullah asked for the whole set (`npx skills add mattpocock/skills`), so all 38 skills are now in `.agents/skills/`, linked from `a local folder`. No app or Pi code changed.
- Careful: these are written for general software work, not for this project. Their advice does not override this file. `code-review` has the same name as a built-in the coding tool command. `git-guardrails-the tool-code` and `setup-pre-commit` change git or agent settings if run, so do not run them unless he asks.
- Tested: 38 folders, 38 working links, 38 lock entries. No skill has been run. The repo's `software-factory` skill was skipped by the installer because of a YAML error in its own file.

### 2026-11-02: Added the grill-me skill
- Changed: Abdullah ran `npx skills add mattpocock/skills --skill=grill-me`. Installed `grill-me` and `grilling` in `.agents/skills/`, linked from `a local folder`, pinned in `skills-lock.json`. `grill-me` only calls `grilling`, so it needs both. No app or Pi code changed.
- Careful: the installer ignores `--skill=name` and installs all 38 skills. Write `--skill name` with a space. The extra 36 were removed.
- Tested: only the files and links were checked. The skill has not been run; a new the coding tool session may be needed before `/grill-me` appears.

### 2026-11-02: Orange redesign reverted
- Decided: Abdullah saw the redesign on his simulator and asked to go back to the old design.
- Changed: reverted commits e6c80e7, 0177046 and d0229d6 (colors, fonts, logo, app icons, screens, `docs/DESIGN.md`). Kept the Arabic food categories and the alert wording. The redesign stays in git history.
- Tested: `flutter analyze`, 35 unit tests, and a screenshot of his simulator after rebuilding it.
- Next: ask him what he disliked: the orange only, or the whole look. Layout and color can change separately.

### 2026-11-02: Redesign installed on his simulator; status bar fixed
- Found: he saw "nothing changed" because the installed app was the old build from the night before. Rebuilt it on his iPhone 16 Pro simulator; his data was backed up first and held no meals.
- Fixed: the clock was white on cream when the app opened to Home, because the dark splash left a light status bar. The tour missed this.
- Tested: `flutter analyze`, unit tests, screenshot on his simulator, connected to the real scale.

### 2026-11-02: New brand and full front-end redesign (commit e6c80e7)
- Decided: Abdullah rejected the old look as only a starter demo, and said icons, images, fonts and colors may all change.
- Changed: new identity in `docs/DESIGN.md`: the letter م on a dial as logo and app icon, date-brown, laban and saffron
  palette, Instrument Serif and Amiri for numbers and titles, IBM Plex Sans Arabic for text, Phosphor icons. Every screen
  rebuilt around `brand.dart`: dark welcome and analyzing screens, Home on the calorie dial, Add Meal with the weight on a
  live dial (one turn = 1 kg), Review with an edge-to-edge photo that collapses into a bar, bar chart in Insights, ledger
  lists, custom tab bar with Add Meal in the middle. Removed unused `miqdar-food.png`.
- Also fixed: food categories in Arabic; alert wording.
- Tested: `flutter analyze`, 35 unit tests; every main screen checked by screenshot in English light and Arabic dark (not
  English dark or Arabic light); `scale_flow_test` on a simulated scale with real Gemini; connection and Zero on the REAL
  scale from the new screens.
- Not tested / risks: real food capture on the real scale; Android build; iPad and desktop layout; the small edit, photo
  and failure sheets were not looked at after the restyle. One real-scale test run hung for over 8 minutes; the rerun passed
  in 11 s and the cause is unknown.
- Careful: `phosphor_flutter` passes `flutter analyze` but does not build on Flutter 3.47. Icon fonts are bundled instead.
- Next: Abdullah to run `./run_simulator.sh` and judge the look; real food capture.

### 2026-11-02: Boot start, tunnel off, documents sorted, first test on the real scale (commit 43dcd74 and the next one)
- Decided: Abdullah said earlier requirements no longer bind the project, and to do what is best. Recorded under Decisions.
- Changed: the scale starts at boot on Wi-Fi only. The tunnel, which was running publicly with the camera open and no
  password, now needs the new "Miqdar Scale + Internet" icon. Removed the made-up `battery_pct`. `run_simulator.sh`
  defaults to the real scale. Pi updated and restarted; calibration unchanged.
- Documents: new `docs/API.md` checked against the code, because the old pages listed routes that do not exist
  (`/api/analyze`, `/sync/meals`). Old material moved to `docs/archive/`. README and mobile README rewritten. 400-sample
  report labelled as placeholder. `HARDWARE_INTEGRATION.md` is now `docs/HARDWARE.md`.
- Tested: 30 Python and 35 app tests. New app on a throwaway simulator against the real scale: connects, reads 0 g, Zero works.
  Startup entry launched by hand in the Pi's desktop session: scale runs, no tunnel.
- Mistake: killing the old terminal on the Pi also stopped the scale, for about a minute. Restarted. Rule added.
- Not tested / risks: real food capture; an actual reboot. `TECHNICAL_REFERENCE.md` was corrected where checked, not line by line.
- Next: put food on the real scale and capture; power-cycle the Pi once.

### 2026-11-02: Organized the repository and created this file (commit f1a015a)
- Changed: Abdullah asked for a shared file so agents stop losing context. Added `AGENTS.md`, `the local tool file` (loads it
  automatically in the coding tool) and `docs/README.md`. Moved the loose root documents into `docs/`; `AGENT_HANDOVER.md`
  is now `docs/TECHNICAL_REFERENCE.md` and the requirements file is `docs/archive/FRONTEND_REQUIREMENTS_V3.md`.
  Moved `test_recognition.py` into `evaluation/`. Scripts and Pi files were deliberately left in place.
- Found: the requirements document lists sign-in and more as P0. The previous agent removed those fake screens after
  checking only the hardware PDF. Abdullah later settled this: no accounts.
- Tested: Python tests and `flutter analyze` pass, all root scripts pass a syntax check, `evaluation/test_recognition.py --help` runs from its new place, no broken document links.
- Not tested / risks: no app or Pi code changed. Other tools (Cursor, Codex and similar) may need to be told to read this file.

### 2026-11-02: Finished the whole app (commit 3b2b262)
- Changed: removed fake sign-in, password reset, pairing, sync, account deletion and device stats. Added a real scale
  connection test, Delete All My Data and honest privacy text. Database v3 now keeps fat/fiber goals, track-only mode,
  meal notes and notice state; meal photos are kept and shown. Demo no longer writes to the real diary. The diary
  filter no longer removes meals elsewhere. A saved capture no longer reopens after restart. A slow Gemini model gets
  a second try when the others fail.
- Tested: 35 unit tests; end-to-end flow on a simulated scale with real Gemini; migration from v2; restart survival;
  buttons tapped on a simulator; screenshots in both languages.
- Not tested / risks: the real scale. Two end-to-end runs timed out while Gemini was overloaded; the retry was added
  after that. Export only copies to the clipboard. Log Again does not carry the photo.

### 2026-11-01: Rebuilt the core app around the real scale (commits 12bead2, d3aabd3)
- Changed: Add Meal has a big live weight and one Capture button. Review keeps Save always visible with Undo. No fake
  meals in totals. Arabic works. Welcome, language, theme and name are remembered.
- Tested: unit tests and flow test on a simulated scale.
- Risk: while testing, the app was uninstalled from his iPhone 16 Pro simulator, wiping its saved meals. Abdullah was told.

### 2026-11-01: Better Gemini analysis and speed (commits 28bf700, a015833, 19775fa)
- Changed: photo sent at 768 px, deadlines of 8 s per model and 35 s total, model fallback list, edible fraction for
  peel and bones, label reading, corrections, calorie plausibility check. The Pi refuses a weight that never settles.
- Tested: real scale with pomegranate (243 g, about 21 s, later faster). A benchmark used up the free daily quota on
  some models. Commit 19775fa says "25 test photos" for its accuracy figure; it was really about 10.
