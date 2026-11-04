# Miqdar app: current screens and controls

This describes the app as it is today. It lists every screen, what sits where from top to bottom, and what each control
does. It was written from the app's code on 2026-11-04 and updated the same day, after the Miqdar design system was
applied. Colors, type and component rules are in [DESIGN.md](DESIGN.md).

## 1. The product

Miqdar (مقدار, "amount") is a senior project: a smart kitchen scale with a phone app, for Saudi and Gulf food. The scale
is a Raspberry Pi with a load cell, a camera and a small touchscreen.

The main flow:

1. The user puts food on the plate. The app shows the live weight, updated twice a second.
2. The user taps Capture. The scale takes a photo and the app receives it.
3. The photo appears immediately with a loading state while Google Gemini identifies the food.
4. Calories are calculated from Gemini's values per 100 g, the edible share of the food, and the measured grams.
5. The user reviews the result, corrects it if needed, and saves it to a diary on the phone.

The app is a phone app built in Flutter with Material 3. It works in English and Arabic (right to left), in light and
dark mode. There are no accounts and no cloud sync.

## 2. What the redesign must keep

**Functions and honesty**

- Every screen and control in this document keeps its function unless the owner agrees to remove it.
- The weight comes from a real scale, so its connection state must always be clear: connected, not connected, sensor
  fault, or simulated.
- Gemini's values are estimates and must be labelled as estimates, never "verified". Show low confidence plainly.
- Each value's source stays visible: official database, typical values, Gemini estimate, entered by hand, or demo.
  The weight's source does too: weighed, entered by hand, standard serving, or estimated.
- A nutrient nobody knows shows "Unknown", not 0.
- Do not add sign-in, pairing or sync screens, and do not invent numbers. The scale has no battery sensor, so never show
  a battery level.
- Sample data appears only in the demo, and the demo saves nothing.
- Privacy & Data must keep saying that food photos go to Google and that the free plan may use them.
- Gemini can be down or out of quota, so Search and Manual entry must stay easy to reach from a failure.

**Language and layout**

- Every screen must work in Arabic, mirrored right to left, and in dark mode. Weight digits stay left to right.
- Arabic text is often longer than English, so buttons and tabs must allow for it.
- Do not use internal terms, requirement codes or timings in the interface.

**Build limits**

- The design must be buildable in Flutter on iPhone first. The wide layout in section 3 also exists.
- Fonts must be bundled with the app. The only bundled font is the icon font; text uses the system font.
- The `phosphor_flutter` icon package does not build on the project's Flutter version. Bundled icon fonts do work.

**A direction already rejected**

On 2026-11-02 the owner tried a full redesign and asked to go back to the green design. The reason was not recorded. That
version used date brown, laban and saffron orange, serif numbers and titles (Instrument Serif, Amiri), IBM Plex Sans
Arabic for text, Phosphor icons, and a calorie dial on Home. Do not bring that look back unless the owner asks.

## 3. Current visual design

White rounded cards on a very pale background, one deep green for actions, warm orange for "look at this". See
[DESIGN.md](DESIGN.md) for every color, type style and rule; the values live in `mobile/lib/theme.dart`.

**Layout:** one scrolling column with 20 px side margins. At 780 px wide or more, the bottom bar becomes a 248 px sidebar
(see section 4), and Home places some cards side by side.

## 4. Navigation

```text
Splash
├─ First time → Welcome
│    ├─ Get Started → Body Profile → Your Daily Goal → Main app
│    └─ Try with Sample Data → Main app (demo)
├─ Returning, no body profile yet → Body Profile → Your Daily Goal → Main app
└─ Returning → Main app

Main app: bottom bar with 5 tabs
├─ Home
│    ├─ Bell → Notices → Daily Goals
│    ├─ Goals → Daily Goals
│    ├─ Add Meal → Add Meal tab
│    ├─ Connect → Scale
│    ├─ Resume → Review Meal
│    ├─ See diary → Diary tab
│    ├─ A meal → Meal Detail
│    └─ See all → Meal Ideas
├─ Add Meal (Scale / Search / Manual) → Review Meal
│    └─ Capture → Analyzing → Review Meal, or Failure sheet
├─ Diary → Meal Detail → Edit sheet, Log Again, Delete
├─ Insights → Export sheet, Nutrient sheet
└─ Profile → Name sheet, Body Profile, Daily Goals, Food Preferences, Scale, Privacy & Data
```

**Bottom bar, left to right:** Home (house), Add Meal (camera with plus, inside an outlined circle, solid green when
selected), Diary (calendar), Insights (rising line), Profile (person). The selected tab has a solid green pill with a
filled icon. Arabic labels: الرئيسية، إضافة وجبة، السجل، التحليلات، ملفي.

**Wide layout sidebar, top to bottom:** the name, Add Meal button, then Home, Add Meal, Diary, Insights and Profile.
At the bottom are Notices with an unread badge, and Scale with the live weight.

**Capture strip:** while the scale or Gemini is working, a thin progress line and a one-line message appear at the top of
every tab, such as "Gemini is analyzing your food (243 g)…".

## 5. Start screens

### Splash

Shown for about a second, then fades out. No controls. Centered: scale icon, "Miqdar • مقدار", and the tagline "Weigh it.
Snap it. Know what you ate."

### Welcome

Shown until the user starts. The layout fills the screen without scrolling.

1. **Top row:** scale icon and name on one side. On the other, a language pill (`العربية` or `EN`, switches at once) and a
   round button that switches light and dark.
2. **Large food photo card**, filling the free space, with sample data on top of it:
   - A white pill: green dot and "380 g • Smart Scale".
   - A dark pill with three small buttons, Kabsa, Shawarma and Jareesh. Each switches the photo and numbers.
   - Thin camera focus corners in the center (decoration).
   - A floating summary card: dish name, sparkle icon, "Sample meal • 380 g", a calories badge, and three pills for
     protein, carbs and fat.
3. **Headline:** "Know what's on your plate, down to the gram."
4. **Text:** "Put your food on the Miqdar scale. It weighs and photographs it, and Gemini estimates the calories and
   nutrients."
5. **Get Started** (dark, full width, arrow): opens Body Profile, then the app with the user's real, empty diary.
6. **Try with Sample Data** (outlined, full width): opens the demo.

### Body Profile

Required for every real user, once: after Get Started, or on the next launch for someone updating the app. The demo skips
it. Test builds show a **Skip** text button at the top; release builds do not. From Profile it opens filled in, with a back arrow.

1. **Text:** the answers calculate the daily goal, stay on this phone and are not sent to Gemini.
2. **First card:** Sex chips (Male, Female). Selecting Female adds "Pregnant or breastfeeding?" with Yes and No. Age, Height (cm)
   and Weight (kg) fields.
3. **"How active are you?"** chips, five levels.
4. **"What is your goal?"** chips: Lose weight, Keep my weight, Gain weight. Losing or gaining adds Target weight and Weekly
   pace (0.25 or 0.5 kg a week).
5. **Calculate My Goal** stays fixed at the bottom. Missing or impossible answers show red messages in place.

### Your Daily Goal

Top bar with a back arrow to correct the answers.

- **With a goal:** "Eat about", an orange **Estimate** pill, calories, protein, carbs and fat. A note if the plan was raised to
  the safe minimum. A caption names the formula and says it is not medical advice. **Use These Goals** is the main button.
  **Keep My Current Goals** appears for anyone who already had goals, not on a first run.
- **Under 18, pregnant or breastfeeding:** no numbers. "Ask a doctor or dietitian", the reason, and **Continue**. On a first
  run this turns on tracking without goals, so the default 2200 kcal does not stand in as a target. Otherwise goals stay as they were.

## 6. Home tab

A scrolling page, top to bottom:

1. **Demo banner**, only in the demo: amber strip, "Demo with sample data. Nothing here is saved."
2. **Header:** a greeting by time of day, with the name below it if the user set one. On the far side is a round outlined
   **bell** with an unread count, which opens Notices.
3. **Day picker,** centered: back arrow, the date or "Today" (opens a calendar, up to a year back), forward arrow
   (disabled on today). This changes the day shown on this screen.
4. **"Meal not saved yet" card,** only with an unsaved result: pale green, meal name and weight, and a **Resume** button
   that reopens Review Meal.
5. **Nutrition card:**
   - Title "Nutrition" and a **Goals** text button that opens Daily Goals.
   - Left: a calorie ring, 152 px, with tick marks, flame icon, calories eaten, "/ 2200 kcal", and a pill such as "2200 left".
     Over the goal, the ring turns orange and the pill says "+120 above".
   - Right: four progress lines for protein, carbs, fat and sugar, each with a colored dot and "0 / 120 g".
   - Below them: three neutral tiles for fiber, sodium and potassium, each with value and goal.
   - In "Just track" mode, goals and "left" are hidden and only amounts show.
6. **Scale card** (dark green gradient):
   - Connected: scale icon and "On the scale: 243 g". A simulated scale adds "Simulated scale, not real food".
   - Not connected or sensor fault: orange icon, "Scale not connected" or "Weight sensor not responding", and a **Connect**
     text button that opens the Scale screen.
   - **Add Meal** (white, full width): goes to the Add Meal tab.
7. **Meals section:** title "Today's Meals" or "Meals on 2 Nov", and a **See diary** text button. Below it are meal rows,
   or an empty card reading "Nothing logged yet."
8. **Meal Ideas section:** sparkle icon, title, and a **See all** text button that opens Meal Ideas. Below it is one of:
   a loading bar, up to two idea cards, or a tappable prompt: "Tell us what you like and what to avoid to get meal ideas."

Default goals: 2200 kcal, protein 120 g, carbs 275 g, fat 70 g, sugar 50 g, fiber 28 g, sodium 2300 mg, potassium 3500 mg.

## 7. Add Meal tab

Title "Add Meal", then a three-part switch: **Scale**, **Search**, **Manual**. Scale is the default.

### Scale mode

**Scale card:**

1. **Status row:** a colored dot and "Scale connected", "Scale not connected", or "Simulated scale, not real food". Tapping
   it opens the Scale Address dialog. When connected, a **Zero** text button sits on the far side.
2. **Live weight,** very large (84 px) with "g". When not connected, a large broken-link icon replaces it.
3. **Guidance line,** which changes with the state:
   - Turn on the scale, then connect to it.
   - Load cell not responding: check the wiring.
   - Put your food on the plate
   - Settling… keep your hands off the plate
   - Ready to capture
   - Taking the photo. Keep your hands off the plate.
   - Gemini is analyzing your food…
4. **Main button,** 58 px, full width:
   - Connected: **Capture** with a camera icon. It is disabled under 5 g or while working, and shows a spinner while working.
     Once a photo is chosen it becomes a secondary button, because Analyze This Photo is then the main action.
   - Not connected: **Connect to Scale**, which opens the Scale Address dialog.
5. **Note field,** when connected: "Note for AI (optional): grilled, no sauce…"

**Mixed plate:** under Capture is **Add Next Food** (outlined). Pressing it weighs and photographs the first food and opens a plate.
While a plate is open, Zero and Capture are hidden and the card shows a row per food (photo, "Food 1", grams), then **Finish** (main button),
**Add Next Food**, and the text buttons **Undo Last Food** and **Cancel Plate**. Refusals appear as a message at the bottom. If the plate got lighter, a dialog offers **Undo Last Food** or **Weigh Again**. If the scale restarted, an orange card says the plate was lost, with **Got It**. Finish opens
the Analyzing screen and then Review Meal.

**Under the card:**

- **Error card,** after a failed analysis of a chosen photo: red tint, title, advice, what was detected, and the buttons
  **Search Food** and **Enter by Hand**. The demo can also show **Use Sample Result**.
- **"Away from the scale?"** with three text buttons:
  - **Take a Photo** opens the camera, then the No Time to Weigh sheet with the photo added.
  - **No Time to Weigh?** opens that sheet.
  - **Use a Photo** expands into a box titled "Choose a photo of your food" with **Choose File**, **Photos** and **Try a sample photo**.

**No Time to Weigh sheet:** explains that Gemini estimates the food and the amount, so the meal is marked as estimated. A description field with
a microphone button (speech only fills the field), **Camera** and **Photos** for an optional photo, and **Get an Estimate**. It opens Review Meal with
an estimated portion; nothing is saved without review. The Failure sheet offers it as **Describe It Instead**.

**After a photo is chosen,** these replace that button:

1. **Photo card,** 236 px: file name pill and a round **X** to remove it at the top, **Change Photo** at the bottom.
2. **Weight card:** "Weight of this food", a **Use scale (243 g)** text button when connected, then **−**, a large editable
   number, **+** (steps of 10 g), and four quick buttons: **100g**, **150g**, **200g**, **300g**.
3. **Analyze This Photo** (green, full width, sparkle), with a spinner and "Analyzing photo & matching nutrition…" while working.

### Search mode

1. **Search field,** English or Arabic, with a clear button.
2. **Category chips,** scrolling sideways: All (38), Traditional Dish, Fruit, Protein, Grain, Legume, Vegetable, Dairy,
   Sandwich, Fast Food, Salad, and Custom if the user has made any.
3. **Recent,** when the search is empty and All is selected: up to five foods you logged, each with its weight and calories. Tapping one opens
   Review Meal with its saved values, so the portion can change before saving. No Gemini request is sent.
4. **Food rows:** icon tile (a verified mark for official records), name, second-language name and preparation, and
   calories per 100 g. Tapping one opens the Portion sheet.
5. **No results:** a card with **Enter It by Hand**, which moves to Manual with the name filled in.

### Manual mode

One card titled "Enter a food by hand", with the text "Copy the values from the label. Leave blank what you do not know; it
shows as Unknown, not zero." Fields in pairs:

| Left | Right |
|---|---|
| Food name * | Arabic name (optional) |
| Label Basis (g), default 100 | Portion (g) *, default 150 |
| Calories (kcal) * | Protein (g) |
| Carbs (g) | Fat (g) |
| Sugar (g) | Sodium (mg) |

**Review** (full width) opens Review Meal. If a required field is missing, a message appears at the bottom of the screen.

## 8. Capture results

### Analyzing screen

Opens by itself when the scale's photo arrives. Top bar "Captured Scale Photo", the photo at 4:3, a spinner, "Gemini is
analyzing your food…", and the weight. No buttons. It gives way to Review Meal or the Failure sheet.

### Failure sheet

Slides up when a scale capture yields no calories. Title (such as "Nothing on the scale", "The weight is still moving",
"Gemini usage limit reached"), the photo if there is one, "The AI saw: …", and advice. Buttons: **Ask Gemini Again** when a
retry is possible, and **Back to Add Meal**.

### Review Meal

Top bar: back arrow, "Review Meal", and a red **Discard** text button that drops the result. **Save to Diary** stays fixed
at the bottom (dark, full width, check mark) however far the page scrolls. It saves, returns to Home, and shows "Saved:
name, 692 kcal" with **Undo** for 5 seconds.

Going back without saving keeps the result, and Home shows the "Meal not saved yet" card.

The page, top to bottom:

1. **Photo,** 16:10. Tapping opens it full screen with zoom and a close button. A corner pill shows "85% sure". Under 60% it
   turns orange: "Gemini is unsure (45%), please check".
2. **Food name,** large, with the other language's name below.
3. **Calories,** 48 px, green. The total weight is on the far side.
4. **Three tiles:** protein, carbs, fat.
5. **Small note,** when relevant: "70% of the weight counted as edible", and Gemini's own comment.
6. **Notice cards,** when saving would pass a goal: "If you save this meal…" and the message.
7. **"Could also be" chips,** when there are alternatives. Tapping one switches the food.
8. **Three small buttons:**
   - **Not right? Tell Gemini,** for Gemini results only. Opens a dialog, "What is it really?", with **Cancel** and **Ask Gemini**.
   - **Change Food** opens the Change Food sheet.
   - **Add Side** opens the Add Side sheet.
9. **Portion card:** **-10g**, an editable weight, **+10g**, and a slider from 10 to 800 g. Numbers update as it changes.
10. **"Also on the plate" card,** if sides were added: name, weight, calories, and a red remove button for each.
11. **Two collapsed sections:**
    - **All nutrients:** the eight-nutrient grid and the source badge.
    - **Meal time & notes:** a summary such as "Lunch • Mon, 1:32 PM". Open, it shows chips for Breakfast, Lunch, Dinner and
      Snack (preselected by time of day), the date with **Change Date**, and a note field of up to 200 characters.

**A mixed plate on Review:** the name is the plate's, and the total comes from all its foods. "On this plate" replaces the alternatives, the
Portion card and Also on the plate: one row per food with its photo, name, grams and calories. Tapping a row opens a sheet with **Type the
Name**, **Search Food**, **Enter by Hand** (values per 100 g, blanks stay Unknown), **Change Weight** and **Remove**. Until every food has a name, the total and macros read Unknown. A food with no name reads "Unknown" in orange, and Save to Diary stays off until
every food has a name. **Add Side** stays. Meal Detail lists the same foods, Edit Meal has no Weight field for them, and Log Again restores them all.

**The Failure sheet for a plate** adds **Name the Foods Myself**, which opens Review with the weights kept and the names empty.

### Sheets opened from Add Meal and Review

| Sheet | Contents |
|---|---|
| **Portion** | Food name, category, a source chip ("USDA FDC" or "Reference"), Standard Servings chips, Portion Weight field, **Use Scale (243g)**, a preview of calories, protein, carbs and fat, and **Review** |
| **Change Food** | "Choose the right food", search field, list of foods with calories per 100 g. Tapping one swaps the food and keeps the weight |
| **Add Side** | "Add Side / Oil / Sauce", search field, weight field (default 50 g), list of foods with calories for that weight and an **Add** button each |
| **Choose Meal Photo** | Opened by Change Photo. Rows: **Files** (highlighted), **Photo Library**, **Camera**, **Scale Camera**, **Sample Photos** |
| **Sample Photos** | Close button and five dishes with thumbnail and portion: Chicken Kabsa, Shawarma, Jareesh, Cheese Pizza, Beef Burger |

## 9. Diary tab

1. Title "Diary".
2. **Search field,** "Search your meals", with a clear button.
3. **Filter chips:** All, Breakfast, Lunch, Dinner, Snack.
4. **Days,** newest first. Each has a heading with the date or "Today" and that day's calories, then its meal rows.

**Empty diary:** a card reading "Your diary is empty. Meals you save will appear here." with an **Add Meal** button, and no
search or chips. **No matches:** "No meals match your search."

**Meal row** (also used on Home): a 52 px photo, or the name's first letter on a neutral tile. Then the name, "Lunch • 1:32 PM • 380 g",
and calories in green on the far side. Tapping opens Meal Detail.

### Meal Detail

Top bar: back arrow and the meal type.

1. Photo at 4:3, if there is one.
2. Name, other-language name, date, time and weight. Calories large (34 px) on the far side.
3. Source badge.
4. Note card, if there is a note.
5. Eight-nutrient grid.
6. **Edit** (green) and **Log Again** (soft green) side by side. Log Again opens Review Meal with the same food and weight.
7. **Delete Meal** (red text): a dialog with **Cancel** and **Delete**, then a message with **Undo** for 8 seconds.

**Edit sheet:** "Edit Meal", a meal type dropdown (Breakfast, Lunch, Dinner, Snack, Meal), Weight, Note, the date with
**Change Date**, a live preview of calories and macros, and **Save Changes**.

## 10. Insights tab

1. **Title** "Insights" and a round **download** button that opens the Export sheet.
2. **Period switch:** 7 Days, 30 Days, 90 Days.
3. **Empty state:** "Nothing to show yet. Save a meal and your averages appear here."

With data:

4. **Two tiles:** Calories per day (with "3 logged days") and Protein per day (with the goal).
5. **"Calories by day":** a line chart, 200 px tall, with a goal line. Tapping a point selects it. Above the chart are the
   date, the meal count and "1800 / 2200 kcal". It includes only days that have meals.
6. **"Where your calories come from":** a donut for protein, carbs and fat with a tappable legend of grams, calories and
   percent. Tapping highlights a slice. A small line explains the 4, 4 and 9 kcal per gram.
7. **"Daily averages":** eight tappable cards, one per nutrient: colored dot, amount and goal, progress bar, "82% of your goal".
   Tapping opens the Nutrient sheet.

8. **"Body weight"** (not in the demo, shown even with no meals), with an **Add** text button. A card shows the latest or chosen weight, a line chart once
   there are two entries (tap to choose a point), and the newest five entries. Tapping an entry opens a sheet to correct or delete it. At 2 kg from the weight behind the
   current goal, an orange card offers new goals with **Update Goal** and **Keep Current Goal**. The sheet says the weight is typed in from a bathroom scale.

**Nutrient sheet:** nutrient name, average and goal, and "Meals with the most": the top five meals.

**Export sheet:** "Export Meals", an explanation, a small scrolling box of text in CSV format, and **Copy**. It copies to the
clipboard; no file is created.

## 11. Profile tab

1. **Title** "Profile".
2. **Hero card** (green gradient): white circle with the name's first letter, the name, "Your diary stays on this phone" (or
   "Demo with sample data"), and a **pencil** that opens the Name sheet: "Your name", a field, **Save**.
3. **Appearance card:**
   - Language: **English** and **العربية** switch.
   - **Dark Mode** switch.
   - **Phone-sized layout** switch, on wide screens only.
4. **Settings,** tappable rows, each with an icon tile, title, subtitle and arrow:
   - **Body Profile,** "165 cm, 70 kg" or "Not filled in yet". Not shown in the demo.
   - **Daily Goals,** "2200 kcal a day" or "Tracking without goals".
   - **Meal Reminders,** "On" or "Off". Not shown in the demo.
   - **Food Preferences,** "Allergies, foods to avoid, meal ideas".
   - **Scale,** "Connected" or "Not connected".
   - **Privacy & Data,** "Where your data goes, export, delete".
5. **Exit Demo** (outlined), only in the demo. Returns to Welcome.

### Daily Goals

Top bar "Daily Goals". **Save Goals** stays fixed at the bottom.

1. **Just track, no goals** switch: "Hides goals and turns off notices". When on, everything below is hidden.
2. Groups of goal rows. Each row has a label, **−**, an editable number with its unit, and **+**:

| Group | Goal | Range | Step |
|---|---|---|---|
| Eat about this much | Calories | 800 to 4500 kcal | 50 |
| | Carbs | 30 to 500 g | 10 |
| | Fat | 20 to 200 g | 5 |
| | Potassium | 1000 to 6000 mg | 100 |
| At least | Protein | 20 to 300 g | 5 |
| | Fiber | 10 to 70 g | 2 |
| No more than | Sugar | 5 to 150 g | 5 |
| | Sodium | 400 to 5000 mg | 100 |

### Meal Ideas and Food Preferences

One screen, titled "Meal Ideas". From Profile, the preferences section starts open. From Home, it starts closed.

1. **"Your preferences"** (expandable):
   - "I am" chips, multiple choice: Managing my weight, Watching sugar, Watching salt, Watching fat, Kidney diet, Vegetarian, Vegan.
   - **Allergies** field, **Foods to avoid** field, **Save**.
2. **Idea cards:** name, Arabic name, portion, a row of numbers for calories, protein and sodium, reasons, and a **Log This**
   button that opens Review Meal. It never logs a meal directly.
3. **No ideas:** "No ideas fit your preferences. Try removing something you excluded."
4. A small disclaimer, when one is provided.

### Scale

Top bar "Scale".

1. **Status card:** a colored dot and one of Connected, Not connected, Weight sensor not responding, or Simulated scale, not
   real food. When connected, also: weight at 52 px, "Steady" or "Settling…", **Zero the Scale**, and "Reading looks wrong?
   Leave only the empty plate on the scale, then zero it."
2. **"To connect" card,** when not connected: three numbered steps and **Try Again**.
3. **Scale address row:** the current address and "Change". Opens the Scale Address dialog.
4. **Automatic capture card,** when connected. Information only, no switch: says whether the scale photographs food by itself.

**Scale Address dialog:** an explanation, an address field, a chip reading "On my Wi-Fi: foodscale.local" that fills the field,
a red message if the address does not answer, then **Cancel** and **Connect** (or **Try Again** after a failure).

### Privacy & Data

1. **"Where your data goes" card,** three rows with icons:
   - **This phone:** meals, photos, goals, preferences and body profile are stored here, with no account or cloud copy. The body
     profile is not sent to Gemini.
   - **Google Gemini:** each photo goes to Google with its weight and any note or description. Speech may also go through Apple's service. The free plan may use it.
   - **Your scale:** it keeps its own photos, and deleting data here does not remove them.
2. **Export My Meals** (outlined): opens the Export sheet for the last 365 days.
3. **Delete All My Data** (red outline, not in the demo): a dialog with **Cancel** and **Delete Everything**, then back to Welcome.
4. **Troubleshooting** (expandable): scale address, scale status, last AI model.

### Meal Reminders

A switch, "Remind me to log meals", off by default. Turning it on asks for notification permission. If refused, an orange card explains how to allow it in
Settings and the switch stays off. When on: Breakfast (8:00), Lunch (13:00) and Dinner (19:00), each with a time button and its own switch.

### Notices

Opened from the bell. Top bar "Notices". Text buttons at the top: **Mark all read** (when there are unread notices) and **Goals**.

**Notice card:** bell icon, "Sodium • Above your goal", a message, and **Got it**. Orange at 125% of a goal or more, blue below that.

**Empty:** a check icon, "No notices. You will see a note here when a meal takes you past a goal."

## 12. Shared components

| Component | Description | Used on |
|---|---|---|
| Card | White rounded card with border and soft shadow, optionally tappable | Everywhere |
| Calorie ring | Solid green ring with tick marks, orange over goal, filling the other way in Arabic | Home |
| Nutrient grid | Eight neutral tiles, two across on phones: colored dot, label, value, or an orange "Unknown" | Review, Meal Detail |
| Source badge | Tinted box with icon and source, plus a pill for the weight's source. Neutral for official and typical values, blue for entered by hand, orange for Gemini estimates and demo | Review, Meal Detail |
| Meal row | Photo, name, details, calories | Home, Diary |
| Notice card | Tinted box with a bell, a message and an optional **Got it** | Notices, Review |
| Idea card | Food suggestion with **Log This** | Home, Meal Ideas |
| Message bar | Floats at the bottom, with **Undo** after saving or deleting | Across the app |

## 13. Weak points in the current design

These come from reading the code. They are observations, not decisions. The design system did not address them.

- **Home is long:** on an iPhone 16 Pro, the Nutrition and scale cards fill the first view. Only the meals heading is
  visible above the bottom bar, so the meals themselves need scrolling.
- **Add Meal appears twice** on the first Home view: as a tab and as the scale card's button.
- **Date navigation only on Home:** Diary has search and filters but cannot jump to a date.
- **Review has many controls:** alternatives, three small buttons, portion, sides and two collapsed sections on one page.
- **Manual form gap:** the form has no fields for fiber or potassium, so they always show as Unknown.
- **No logo:** the design system has none yet, so the name is set in type, with a generic scale icon on Splash and Welcome.
