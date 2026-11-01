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

*Update this section whenever it stops being true. Last updated 2026-11-02.*

- **Branch:** `feature/scale-live-flow` holds all current work. `main` is 13+ commits behind and `origin/usb` is
  an older copy. Do not merge to `main` until Abdullah says so.
- **App:** every main screen is redone in English and Arabic, light and dark, and passes tests on a **simulated** scale.
- **Not yet tested on the real scale:** the redone app, the Cloudflare tunnel, USB-C networking (Mac → Pi gets no
  answers; Wi-Fi is used instead).
- **Last real-scale test:** 2026-11-01, on the previous app design: chili sauce and pomegranate end to end.
- **Real scale reading:** it last showed `-33.6 g`, so it needs Zero with the empty plate.
- **Gemini:** free plan. Flash models allow about 20 requests a day per model. On 2026-11-02 the main model was
  overloaded and the last fallback was out of quota.

## Where things live

```
AGENTS.md                 This file
CLAUDE.md                 Makes Claude Code load this file automatically
README.md                 Project overview
app.py                    Runs on the Pi: scale screen, REST API on :8080, capture
hardware.py, scale.py     HX711 and camera drivers; calibration tool
scale_calibration.json    Calibration values, tracked in git
start_all.sh              What the Pi desktop icon runs: tunnel + fullscreen scale
start_scale_app.sh        Start the scale app (--headless --mock simulates it on a Mac)
start_cloudflare_tunnel.sh, start_server.sh
install_pi_desktop.sh     Pi setup. Run again after every git pull on the Pi
enable_usb_ssh_pi.sh      Pi: USB-C network (not working yet, see Current state)
connect_pi.sh             Mac: terminal on the Pi
run_simulator.sh          Mac: run the app with the key from .env
run_checks.sh             Rebuilds the database, then runs all tests
mobile/lib/
  app_controller.dart     App state; capture flow; saving
  services/               gemini_service (prompt, model order), api_service (scale), alert_service
  data/                   local_database (SQLite v3, meal photos), food_catalog
  models/nutrition.dart   Data models
  l10n/strings.dart       English and Arabic text, s.tr(en, ar), s.date(...)
  ui/                     Screens; ui/widgets/charts_and_gauges.dart for shared widgets
mobile/test/              Unit tests
mobile/integration_test/  scale_flow_test: end-to-end flow on a simulator
backend/                  Python service and tests (old path, /recommendations, goals)
database/                 Food database, seeds and build scripts
evaluation/               Benchmark tools and test_recognition.py. The 400-sample data is placeholder
docs/                     All other documents, listed in docs/README.md
```

**Do not move or rename** `app.py`, `hardware.py`, `scale.py`, `scale_calibration.json`, `requirements.txt` or the
root `.sh` scripts. The Pi's desktop icon and installed setup use those exact paths, and the scripts and tests refer
to each other.

## Commands

```bash
./run_simulator.sh http://foodscale.local:8080            # the app, connected to the real scale
./run_simulator.sh                                        # the app, connected to a scale API on this Mac
./start_scale_app.sh --headless --mock                    # simulated scale; add --auto-capture for scale_flow_test
cd mobile && flutter analyze && flutter test              # app checks
PYTHONPATH=backend .venv/bin/python -m unittest discover -s backend/tests    # Python tests
ssh miqdar-pi                                             # the Pi (user foodscale, repo ~/Miqdar), over Wi-Fi
```

On the Pi after new code: `git pull origin feature/scale-live-flow && ./install_pi_desktop.sh`.

## Rules

**Safety**
- Keep the Gemini key only in `.env`, which git ignores. GitHub rejects pushes containing keys.
- Do not start or test a public tunnel casually: it exposes the camera and API. `MIQDAR_API_TOKEN` can protect them.
- Commit or push only on Abdullah's request or when his request clearly includes it. Never to `main` without asking.

**Protecting his data**
- Run integration tests on a throwaway simulator (`xcrun simctl create`), never on his iPhone 16 Pro simulator.
  `flutter test` reinstalls the app and wipes that simulator's saved meals. This has already happened twice.
- Running the simulated scale changes the tracked `database/miqdar_nutrition.db`. Restore it with
  `git checkout -- database/miqdar_nutrition.db` before committing, unless the change is intended.
- Restart the simulated scale between test runs, or the last capture reopens as a new review.

**App honesty**
- Do not add a screen that looks like sign-in, pairing or sync unless it really does that. No fake numbers
  (the Pi's API still returns a made-up `battery_pct`, so do not show it).
- The default diary holds only real meals. Sample meals exist only in the demo (`account.isDemo`), which must never
  write to the database.
- Gemini values are estimates and must be labelled as such, never "verified".
- Privacy & Data states that food photos go to Google and that the free plan may use them. Keep this true.
- Do not present the 400-sample evaluation as real results.

**Code**
- All user-facing text goes through `s.tr(en, ar)`, and dates through `s.date(...)`. Check Arabic and dark mode.
- A database column change needs a version bump and a migration in `local_database.dart`.
- No screen-code jargon in the interface (S36, PRD-07, ms timings).
- Saying "works" means you ran it. A passing test on the simulated scale does not prove the real scale works.
- Gemini can misname food (it read one Jareesh photo as both Jareesh and Saleeg). Tests must not require an exact dish name.

**Pi hardware**
- `pkill -f "app.py"` over SSH kills your own shell. Use `pkill -f "[a]pp.py"`.
- A Mac IDE blocked by macOS Local Network privacy shows `No route to host`. That is not a hotspot problem.
- A plain virtualenv cannot import `lgpio` and `picamera2`; it must use `--system-site-packages`.

## Decisions Abdullah made

- Gemini analyzes every food. No database lookup or repeated stored foods for the scale flow, because ingredients change.
- The Gemini key lives on the app side, not on the Pi.
- Add Meal shows the live weight and a Capture button. The photo appears immediately with loading, then the food name and calories.
- Agents have full freedom on UX and AI choices, as long as nothing gets blocked. He wants the best result, not literal obedience.
- The 400-sample benchmark is fake placeholder data: ignore it.

## Open decisions

Waiting for Abdullah. Do not settle these alone.

1. **Sign-in, password reset, pairing, account deletion and sync (2026-11-02).** `docs/FRONTEND_REQUIREMENTS_V3.md`
   lists these as P0 (S03, S04, S06, S10, S43, S48, S49) and demands genuine ones. The old screens were fake, so they
   were removed; the requirements are therefore not met. Real versions need an auth backend. Either build them or
   confirm with the supervisor that a phone-only diary is acceptable.
2. **Auto-start the scale at boot, and turn the tunnel off by default.** Recommended, not done.
3. **Enable Gemini billing** for reliability during the demo. Recommended, his cost to decide.
4. **Remove the food-list Change Food / Add Side** now that Gemini analyzes everything, or keep them?
5. **Finish the USB-C cable connection**, or stay on Wi-Fi?
6. **Public repository contains the Pi hotspot password** in `docs/HARDWARE_INTEGRATION.md` and the handover PDFs.
   Change that password on the devices, or make the repository private.
7. **Merge to `main`.** Only when he says.

## Change log

Newest first. Older history: `git log` and `docs/CHANGELOG_1.1.md`.

### 2026-11-02: Organized the repository and created this file (commit 04df902)
- Changed: Abdullah asked for a shared file so agents stop losing context. Added `AGENTS.md`, `CLAUDE.md` (loads it
  automatically in Claude Code) and `docs/README.md`. Moved the loose root documents into `docs/`; `AGENT_HANDOVER.md`
  is now `docs/TECHNICAL_REFERENCE.md` and the requirements file is `docs/FRONTEND_REQUIREMENTS_V3.md`.
  Moved `test_recognition.py` into `evaluation/`. Scripts and Pi files were deliberately left in place.
- Found: the requirements document lists sign-in and more as P0. The previous agent removed those fake screens after
  checking only the hardware PDF. Recorded as open decision 1.
- Tested: Python tests and `flutter analyze` pass, all root scripts pass a syntax check, `evaluation/test_recognition.py --help` runs from its new place, no broken document links.
- Not tested / risks: no app or Pi code changed. Other tools (Cursor, Codex and similar) may need to be told to read this file.

### 2026-11-02: Finished the whole app (commit dd36652)
- Changed: removed fake sign-in, password reset, pairing, sync, account deletion and device stats. Added a real scale
  connection test, Delete All My Data and honest privacy text. Database v3 now keeps fat/fiber goals, track-only mode,
  meal notes and notice state; meal photos are kept and shown. Demo no longer writes to the real diary. The diary
  filter no longer removes meals elsewhere. A saved capture no longer reopens after restart. A slow Gemini model gets
  a second try when the others fail.
- Tested: 35 unit tests; end-to-end flow on a simulated scale with real Gemini; migration from v2; restart survival;
  buttons tapped on a simulator; screenshots in both languages.
- Not tested / risks: the real scale. Two end-to-end runs timed out while Gemini was overloaded; the retry was added
  after that. Export only copies to the clipboard. Log Again does not carry the photo.

### 2026-11-01: Rebuilt the core app around the real scale (commits 5304d4b, 5ac29bc)
- Changed: Add Meal has a big live weight and one Capture button. Review keeps Save always visible with Undo. No fake
  meals in totals. Arabic works. Welcome, language, theme and name are remembered.
- Tested: unit tests and flow test on a simulated scale.
- Risk: while testing, the app was uninstalled from his iPhone 16 Pro simulator, wiping its saved meals. Abdullah was told.

### 2026-11-01: Better Gemini analysis and speed (commits 465b087, 0045d74, ab0ad80)
- Changed: photo sent at 768 px, deadlines of 8 s per model and 35 s total, model fallback list, edible fraction for
  peel and bones, label reading, corrections, calorie plausibility check. The Pi refuses a weight that never settles.
- Tested: real scale with pomegranate (243 g, about 21 s, later faster). A benchmark used up the free daily quota on
  some models. Commit ab0ad80 says "25 test photos" for its accuracy figure; it was really about 10.
