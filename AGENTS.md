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

*Update this section whenever it stops being true. Last updated 2026-11-04.*

- **Branch:** `feature/scale-live-flow` holds all current work, and the Pi is on it. `main` is well behind and
  `origin/usb` is an older copy. Do not merge to `main` until Abdullah says so.
- **App:** follows the Miqdar design system from a design tool (`docs/DESIGN.md`), in English and Arabic, light and dark. There are no accounts, by decision.
- **Real scale, new app, verified 2026-11-02:** connects at `foodscale.local`, shows the true reading (0 g, sensor ok),
  Zero works, and an empty-plate capture is refused.
- **Still not verified on the real scale:**
  1. A real food capture with the new app: nobody was there to put food on the plate. This is the most important next test.
  2. Starting at boot: the startup entry was launched by hand and worked, but the Pi has not been rebooted, because
     `sudo reboot` needs a password. Power-cycle it once to prove this.
- **Pi:** tunnel off by default and not running. The scale's Wi-Fi address works.
- **Not working:** USB-C networking (Mac → Pi gets no answers). Wi-Fi is used instead, and this is not being pursued.
- **Gemini:** free plan. Flash models allow about 20 requests a day per model. On 2026-11-02 the main model was
  overloaded and the last fallback was out of quota.
- **Next work:** the plan is GitHub issue #1, split into tickets #2 to #13. Body profile (#2, #3) is built. Work the rest in ticket order.
- **Agent skills setup:** `/setup-matt-pocock-skills` was started but not finished, so `docs/agents/` does not exist. Tickets use the `ready-to-build` label, not the skills' default name.

## Where things live

```
AGENTS.md                 This file
the local tool file                 Makes the coding tool load this file automatically
.agents/skills/           38 agent skills from mattpocock/skills, plus frontend-design from a public skills repo; a local folder links to them. skills-lock.json pins them
README.md                 Project overview
app.py                    Runs on the Pi: scale screen, REST API on :8080, capture
hardware.py, scale.py     HX711 and camera drivers; calibration tool
scale_calibration.json    Calibration values, tracked in git
start_all.sh              What boot and the Pi icons run: fullscreen scale; --tunnel adds the public address
start_scale_app.sh        Start the scale app (--headless --mock simulates it on a Mac)
start_cloudflare_tunnel.sh, start_server.sh
install_pi_desktop.sh     Pi setup, desktop icons, start at boot. Run again after every git pull on the Pi
enable_usb_ssh_pi.sh      Pi: USB-C network (not working, see Current state)
connect_pi.sh             Mac: terminal on the Pi
run_simulator.sh          Mac: run the app with the key from .env, on the real scale by default
run_checks.sh             Rebuilds the database, then runs all tests
mobile/lib/
  app_controller.dart     App state; capture flow; saving
  services/               gemini_service (prompt, model order), api_service (scale), alert_service
  data/                   local_database (SQLite v4, meal photos), food_catalog
  models/nutrition.dart   Data models
  models/body_profile.dart  Body profile and the goal calculation
  theme.dart              All colors (context.mq) and text styles (MiqdarType)
  miqdar_icons.dart       Icons from mobile/assets/fonts, generated; see the README there
  l10n/strings.dart       English and Arabic text, s.tr(en, ar), s.date(...)
  ui/                     Screens; ui/widgets/charts_and_gauges.dart for shared widgets
mobile/test/              Unit tests
mobile/integration_test/  scale_flow_test: end-to-end flow on a simulator
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

## Decisions Abdullah made

- Gemini analyzes every food. No database lookup or repeated stored foods for the scale flow, because ingredients change.
- The Gemini key lives on the app side, not on the Pi.
- Add Meal shows the live weight and a Capture button. The photo appears immediately with loading, then the food name and calories.
- Agents have full freedom on UX and AI choices, as long as nothing gets blocked. He wants the best result, not literal obedience.
- The 400-sample benchmark is fake placeholder data: ignore it.
- 2026-11-02: he tried the orange brand redesign (commit 199e6dd) on his simulator, did not like it, and asked for the previous green design back. Do not bring back the orange look unless he asks. The earlier request to improve the design is still open: ask him what he wants before another redesign.
- 2026-11-02: earlier requirements no longer bind the project, including `docs/archive/FRONTEND_REQUIREMENTS_V3.md`. No accounts or sign-in; the diary stays on the phone. "You are one of us, do the best for the project": act on your own judgment and report plainly.
- 2026-11-04: he made a design system in a design tool and asked for it to be applied ("do it"). It replaces the green design as the app's look. It keeps a green, in a deeper shade, with orange as the attention color.
- 2026-11-04: new feature plan, in issue #1. Priority is daily use, with the most effort on what will be demonstrated. Build one at a time: body profile and goal; mixed plates; logging away from the scale (phone camera, describe by text or voice, as a secondary option); quick re-logging from Search; body weight log; meal reminders.
- 2026-11-04: the profile is required for every user, but skippable in test builds while he tests. Rice with chicken added as one plate is one meal. Adding the next food uses a button on both screens, not automatic detection. Short wobbles of the weight are accepted.
- 2026-11-04: features that do not use the scale need no hardware testing. He will come back to agents when he is ready for a real-meal accuracy test.

## Open decisions

Waiting for Abdullah. Do not settle these alone.

1. **Public repository contains the Pi hotspot password** in `docs/HARDWARE.md`, and possibly the PDFs in
   `docs/archive/handover/`. Deleting it from current files does not remove it from git history. Change the password on
   the devices (Wi-Fi and Pi login), or make the repository private. Going private also needs login on the Pi for `git pull`.
2. **Enable Gemini billing.** On 2026-11-04 he chose to stay on the free plan for now and pay later if other people will test the app.
3. **Merge to `main`.** Only when he says.

Settled 2026-11-02: boot start and tunnel off (done); Change Food and Add Side stay, because they are the way to log food
when Gemini is down; USB-C is dropped in favor of Wi-Fi.

## Change log

Newest first. Older history: `git log` and `docs/CHANGELOG_1.1.md`.

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

### 2026-11-04: Applied the a design tool design system to the whole app
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
- Changed: reverted commits 199e6dd, cc952a6 and 3748a71 (colors, fonts, logo, app icons, screens, `docs/DESIGN.md`). Kept the Arabic food categories and the alert wording. The redesign stays in git history.
- Tested: `flutter analyze`, 35 unit tests, and a screenshot of his simulator after rebuilding it.
- Next: ask him what he disliked: the orange only, or the whole look. Layout and color can change separately.

### 2026-11-02: Redesign installed on his simulator; status bar fixed
- Found: he saw "nothing changed" because the installed app was the old build from the night before. Rebuilt it on his iPhone 16 Pro simulator; his data was backed up first and held no meals.
- Fixed: the clock was white on cream when the app opened to Home, because the dark splash left a light status bar. The tour missed this.
- Tested: `flutter analyze`, unit tests, screenshot on his simulator, connected to the real scale.

### 2026-11-02: New brand and full front-end redesign (commit 199e6dd)
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

### 2026-11-02: Boot start, tunnel off, documents sorted, first test on the real scale (commit 7f41667 and the next one)
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

### 2026-11-02: Organized the repository and created this file (commit 04df902)
- Changed: Abdullah asked for a shared file so agents stop losing context. Added `AGENTS.md`, `the local tool file` (loads it
  automatically in the coding tool) and `docs/README.md`. Moved the loose root documents into `docs/`; `AGENT_HANDOVER.md`
  is now `docs/TECHNICAL_REFERENCE.md` and the requirements file is `docs/archive/FRONTEND_REQUIREMENTS_V3.md`.
  Moved `test_recognition.py` into `evaluation/`. Scripts and Pi files were deliberately left in place.
- Found: the requirements document lists sign-in and more as P0. The previous agent removed those fake screens after
  checking only the hardware PDF. Abdullah later settled this: no accounts.
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
