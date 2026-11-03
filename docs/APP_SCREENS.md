# Miqdar app: current screens and controls

This describes the app as it is today, as a starting point for a redesign. It lists every screen, what sits where from
top to bottom, and what each control does. It was written from the app's code on 2026-11-04 and checked against one
screenshot (Home, empty day). Other screens were not checked by eye, so exact appearance may differ slightly.

No redesign direction is set here. Ask the owner what they want before choosing a look.

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
- Fonts must be bundled with the app. No custom fonts are bundled today.
- The `phosphor_flutter` icon package does not build on the project's Flutter version. Bundled icon fonts do work.

**A direction already rejected**

On 2026-11-02 the owner tried a full redesign and asked to go back to the green design. The reason was not recorded. That
version used date brown, laban and saffron orange, serif numbers and titles (Instrument Serif, Amiri), IBM Plex Sans
Arabic for text, Phosphor icons, and a calorie dial on Home. Do not bring that look back unless the owner asks.

## 3. Current visual design

**Style:** white rounded cards on a very pale green-grey background, emerald green as the main color, heavy bold type.

| Role | Light | Dark |
|---|---|---|
| Page background | `#F4F7F5` | `#0A120E` |
| Card | `#FFFFFF` | `#182920` |
| Card border | `#E2E8F0` | `#263E31` |
| Main text | `#0F172A` | `#F1F5F9` |
| Secondary text | `#475569` | `#94A3B8` |
| Main green | `#059669` | `#34D399` (text and icons), `#10B981` (buttons) |
| Dark green button | `#112A20` | `#10B981` |
| Selected or soft green | `#ECFDF5` | `#064E3B` |
| Hero gradient | `#042F2E` → `#065F46` → `#059669` | `#06281E` → `#064E3B` → `#047857` |

Status colors: warning `#D97706`, danger `#E11D48`, info `#0284C7`.

Each nutrient has its own color: calories `#059669`, protein `#0D9488`, carbs `#D97706`, fat `#3B82F6`, sugar `#EC4899`,
fiber `#16A34A`, sodium `#6366F1`, potassium `#8B5CF6`.

**Type:** the system font (SF Pro on iPhone), very heavy weights. Screen titles about 24 px, card titles 15 to 18 px, body
12 to 14 px. The largest numbers are the live weight at 84 px and calories on Review at 48 px.

**Shapes:** cards 22 px radius with a thin border and a soft shadow. Buttons 16 to 18 px radius and 52 to 58 px tall.
Bottom sheets have a 28 px top radius, dialogs 24 px. Status labels are full pills.

**Icons and images:** rounded Material icons. Food photos are real photos. The logo image appears only in the wide
sidebar. The splash and Welcome screens use a white scale icon on a dark green rounded square.

**Layout:** one scrolling column with 20 px side margins. At 780 px wide or more, the bottom bar becomes a 248 px sidebar
(see section 4), and Home places some cards side by side.

## 4. Navigation

```text
Splash
├─ First time → Welcome
│    ├─ Get Started → Main app
│    └─ Try with Sample Data → Main app (demo)
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
└─ Profile → Name sheet, Daily Goals, Food Preferences, Scale, Privacy & Data
```

**Bottom bar, left to right:** Home (house), Add Meal (camera with plus, inside a tinted circle, solid green when
selected), Diary (calendar), Insights (rising line), Profile (person). The selected tab has a soft green pill behind its
icon and a green label. Arabic labels: الرئيسية، إضافة وجبة، السجل، التحليلات، حسابي.

**Wide layout sidebar, top to bottom:** logo and name, Add Meal button, then Home, Add Meal, Diary, Insights and Profile.
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
5. **Get Started** (dark, full width, arrow): opens the app with the user's real, empty diary.
6. **Try with Sample Data** (outlined, full width): opens the demo.

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
     Over the goal, the ring turns amber and the pill says "+120 above".
   - Right: four progress lines for protein, carbs, fat and sugar, each with a colored dot and "0 / 120 g".
   - Below a divider: three tinted tiles for fiber, sodium and potassium, each with value and goal.
   - In "Just track" mode, goals and "left" are hidden and only amounts show.
6. **Scale card** (dark green gradient):
   - Connected: scale icon and "On the scale: 243 g".
   - Not connected: amber icon, "Scale not connected", and a **Connect** text button that opens the Scale screen.
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
   - Not connected: **Connect to Scale**, which opens the Scale Address dialog.
5. **Note field,** when connected: "Note for AI (optional): grilled, no sauce…"

**Under the card:**

- **Error card,** after a failed analysis of a chosen photo: red tint, title, advice, what was detected, and the buttons
  **Search Food** and **Enter by Hand**. The demo can also show **Use Sample Result**.
- **Use a photo instead** (text button), which expands into a box titled "Choose a photo of your food" with **Choose File**,
  **Photos** and **Try a sample photo**.

**After a photo is chosen,** these replace that button:

1. **Photo card,** 236 px: file name pill and a round **X** to remove it at the top, **Change Photo** at the bottom.
2. **Weight card:** "Weight of this food", a **Use scale (243 g)** text button when connected, then **−**, a large editable
   number, **+** (steps of 10 g), and four quick buttons: **100g**, **150g**, **200g**, **300g**.
3. **Analyze This Photo** (green, full width, sparkle), with a spinner and "Analyzing photo & matching nutrition…" while working.

### Search mode

1. **Search field,** English or Arabic, with a clear button.
2. **Category chips,** scrolling sideways: All (38), Traditional Dish, Fruit, Protein, Grain, Legume, Vegetable, Dairy,
   Sandwich, Fast Food, Salad, and Custom if the user has made any.
3. **Food rows:** icon tile (a verified mark for official records), name, second-language name and preparation, and
   calories per 100 g. Tapping one opens the Portion sheet.
4. **No results:** a card with **Enter It by Hand**, which moves to Manual with the name filled in.

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
   turns amber: "Gemini is unsure (45%), please check".
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

**Meal row** (also used on Home): a 52 px photo, or the name's first letter on a tint. Then the name, "Lunch • 1:32 PM • 380 g",
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
4. **Settings,** four tappable rows, each with an icon tile, title, subtitle and arrow:
   - **Daily Goals,** "2200 kcal a day" or "Tracking without goals".
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
2. **Idea cards:** icon, name, Arabic name, portion pill, badges for calories, protein and sodium, reasons, and a **Log This**
   text button that opens Review Meal. It never logs a meal directly.
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
   - **This phone:** meals, photos, goals and preferences are stored here, with no account or cloud copy.
   - **Google Gemini:** each photo goes to Google with its weight and any note. The free plan may use it.
   - **Your scale:** it keeps its own photos, and deleting data here does not remove them.
2. **Export My Meals** (outlined): opens the Export sheet for the last 365 days.
3. **Delete All My Data** (red outline, not in the demo): a dialog with **Cancel** and **Delete Everything**, then back to Welcome.
4. **Troubleshooting** (expandable): scale address, scale status, last AI model.

### Notices

Opened from the bell. Top bar "Notices". Text buttons at the top: **Mark all read** (when there are unread notices) and **Goals**.

**Notice card:** bell icon, "Sodium • Above your goal", a message, and **Got it**. Amber at 125% of a goal or more, blue below that.

**Empty:** a check icon, "No notices. You will see a note here when a meal takes you past a goal."

## 12. Shared components

| Component | Description | Used on |
|---|---|---|
| Card | White rounded card with border and soft shadow, optionally tappable | Everywhere |
| Calorie ring | Green gradient ring with tick marks and a glowing tip, amber over goal | Home |
| Nutrient grid | Eight tiles, two across on phones: icon tile, label, value, or an amber "Unknown" | Review, Meal Detail |
| Source badge | Tinted box with icon and source, plus a pill for the weight's source. Green for official, blue for entered by hand, amber otherwise | Review, Meal Detail |
| Meal row | Photo, name, details, calories | Home, Diary |
| Notice card | Tinted box with a bell, a message and an optional **Got it** | Notices, Review |
| Idea card | Food suggestion with **Log This** | Home, Meal Ideas |
| Message bar | Floats at the bottom, with **Undo** after saving or deleting | Across the app |

## 13. Weak points in the current design

These come from reading the code. They are observations, not decisions.

- **Phone camera is hard to reach:** it appears only in Choose Meal Photo, which opens from Change Photo, so a photo must
  already be chosen first. The "Choose a photo" box offers only files, photos and samples.
- **Two main button colors:** Capture and Analyze are bright green, while Get Started and Save to Diary are dark green.
- **Colors set outside the shared theme:** Welcome, Add Meal and Review use many of their own color values, so they differ
  slightly from the other screens.
- **Home is long:** on an iPhone 16 Pro, the Nutrition and scale cards fill the first view. Only the meals heading is
  visible above the bottom bar, so the meals themselves need scrolling.
- **Add Meal appears twice** on the first Home view: as a tab and as the scale card's button.
- **Date navigation only on Home:** Diary has search and filters but cannot jump to a date.
- **Review has many controls:** alternatives, three small buttons, portion, sides and two collapsed sections on one page.
- **Manual form gap:** the form has no fields for fiber or potassium, so they always show as Unknown.
- **Uneven Arabic:** Insights is التحليلات on the tab but الإحصاءات as its title. Profile is حسابي ("my account") although there
  are no accounts. Some small text stays in English, such as "kcal/100g" in Change Food and "-10g" on Review.
- **Logo barely used:** the logo image appears only in the wide sidebar, and the phone screens use a generic scale icon.
- **Unused pieces:** a glass card, a camera aiming overlay and `miqdar-food.png` exist in the code but appear on no screen.
