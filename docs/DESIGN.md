# Miqdar design system

The app follows the Miqdar design system Abdullah made, in the version he asked to apply on 2026-11-05. It is black and white,
with big type and real food photos. The original is private to him. This page holds what an agent needs when changing the app.
If the design system changes, update `mobile/lib/theme.dart` and this page.

## In the code

| What | Where |
|---|---|
| Colors, for light and dark | `MiqdarTokens` in `mobile/lib/theme.dart`. Use `context.mq.ink`, never a color value in a screen |
| Text styles | `MiqdarType` in `mobile/lib/theme.dart` |
| Fonts | Thmanyah, in `mobile/assets/fonts/thmanyah/`. Not in git; see below |
| Icons | `MiqdarIcons` in `mobile/lib/miqdar_icons.dart`. To add one, see `mobile/assets/fonts/README.md` |
| Shared components | `mobile/lib/ui/widgets/charts_and_gauges.dart` |
| Floating scale bar and tab capsule | `_ScaleBar`, `_TabCapsule` and `_FloatingBars` in `mobile/lib/ui/screens.dart` |
| Button styles | `FilledButton` is the main ink pill, `FilledButton.tonal` is secondary, `OutlinedButton` is outline, `TextButton` is text |

## The fonts and their licence

Thmanyah's licence is inside the font files. It allows embedding the fonts in the built app. It forbids uploading or hosting
the files anywhere, and forbids changing them, which includes cutting them down. This repository is public, so:

- `mobile/assets/fonts/thmanyah/` and the zips are ignored by git. Never commit them, and never subset them.
- `mobile/assets/fonts/install_thmanyah.sh` installs them from the official zips. `./run_simulator.sh` runs it when needed.
- A fresh clone does not build until that script has run on that Mac.

## Rules

**Honest numbers**
- Always show where values came from (`AiVerificationBadge`), on Review and Meal Detail. Gemini results are estimates, never "verified".
- A nutrient nobody knows reads **Unknown**, never 0.
- Wherever a weight appears, make the scale's state clear with its words: connected, not connected, weight sensor not
  responding, or simulated. Never show a battery level.

**Actions**
- One main action per screen: a single `FilledButton`, an inverted ink pill, black in light and white in dark. 56 px at the
  bottom of a screen (`Size.fromHeight(56)`), 48 by default, 40 inside cards.
- Every button is a pill. Green is never a button fill.
- Destructive actions are `danger` text, never filled and never outlined.
- When Gemini is down or out of quota, Search and Manual entry stay one tap away.

**Color**
- Let the food be the color. Screens are pure white or pure black (`bg`).
- `surface` for filled containers on `bg`, `surfaceSunken` for things inside a `surface`. `SurfaceCard` handles this for its
  children: fields, chips, pills and secondary buttons inside it switch to `surfaceSunken` on their own.
- `border` is for full-bleed hairlines only, never around a card.
- `primary` (green) carries meaning only: selected chip, live scale dot, calorie progress, Add Meal, the profile initial,
  switches, text links. Never a large panel, and never green on green.
- `accent` (orange) means "look at this", not an error: over a goal, scale not connected, low confidence, Unknown. Use
  `accentInk` for its text and small icons.
- `danger` is for destructive actions and failures. `info` is for neutral notices and hand-entered values.
- Each nutrient owns a mark color (`nProtein` and so on) for dots, bars and charts. Names and values, calories included, stay `ink`.

**Type**
- Thmanyah Sans for the interface and every number. Thmanyah Serif Display for screen and section titles and the profile name,
  nothing under 20 px. Thmanyah Serif Text only for long reading (`MiqdarType.reading`): Privacy & Data, Welcome.
- Weights 400, 500 and 700. The family has no 600 or 800, so strong text is 700.
- One `titleScreen` per screen, start-aligned, with no card behind it. Numbers stay left to right in Arabic.
- Thmanyah's digits are proportional and it has no tabular feature. A number that updates live goes through `LockedNumber`.

**Layout**
- Hierarchy comes from size and weight, not boxes. 40 px between sections, 20 px screen margins.
- Sections use `MiqdarSectionHeader`, with a chevron instead of a "See all" button.
- Meal lists are bare rows (`MealRowCard`). Settings are `MiqdarListGroup`s of `MiqdarSettingsRow`s. No cards around lists and no icon tiles.
- Cards only where content needs a ground: Nutrition, an idea, a form, a chart.
- The tabs float, so a tab's list ends with `MediaQuery.paddingOf(context).bottom + 24` of padding to clear them.
- Chip and filter rows bleed off the screen edge so people can see they scroll.

**Shape**
- Cards 24 px, photos and fields 16, thumbnails and tiles 12, sheets 28 on the top corners, everything else a pill.
- Only floating things cast a shadow (`floatShadow`). Touch targets never go below 40 px.

**Language**
- Every screen mirrors in Arabic and works in dark mode. Leave room for longer Arabic text; do not fix button or tab widths.
- Plain, friendly, second person. No exclamation marks or emoji. Title Case for buttons, tabs and screen titles in English;
  sentence case elsewhere. Meta lines are joined with " · ", and units follow a space.

**Do not**
- Bring back the rejected date-brown, laban and saffron look, or serif numbers.
- Bring back the green gradient hero or the deep green palette the 2026-11-04 version used.
- Add sign-in, pairing, sync or battery screens, or invent numbers.
- Use `phosphor_flutter`, which does not build on this Flutter version.
- Use gradients other than the fade under the floating bars and dark scrims over photos, colored left borders, or
  illustrations of food. Food photos are real photos.

## Motion

All of it lives in `mobile/lib/ui/motion.dart` (`MiqdarMotion`). Motion is there to show where something came from and
where it went, never to decorate. Abdullah asked on 2026-11-08 for it to help use the app, not to show off.

- **Curves:** `travel` for anything that crosses the screen (screens, photos, Add Meal), the same both ways so things
  that move together stay together; `settle` for small things (the tab pill, numbers). No bounce or overshoot: he
  rejected the splash's spring shake.
- **Short:** tabs 220 ms, screens 400 ms in and 340 ms back, Add Meal 440 ms open and 360 ms closed. The new screen
  takes taps at once; nothing waits for an animation to end.
- **Screens** arrive from the trailing edge (the left in Arabic) and the one beneath slides back a quarter and dims.
  The iOS edge swipe still goes back, from the right edge in Arabic. `motion_test.dart` checks it.
- **Add Meal** grows out of what was tapped: the scale bar, or the green Add Meal circle (also the default from other
  buttons), and shrinks back into it when another tab opens.
- **Tabs** fade through: the old tab fades out, then the new one fades in from the side of its tab. The tab pill slides.
- **A meal's photo** flies between its row and Meal Detail.
- **Home's calorie number** counts up with its ring.
- **Reduce Motion** turns all of it into plain cuts or fades.
- **Do not** add entrance animations to lists or cards, or motion nobody asked for by tapping. Transitions must never
  rebuild the screen they wrap: keep the same widgets at rest and in motion, or the screen loses its state.

## Differences from the design system

- A field's label sits inside its filled ground and floats up when typing, rather than above the field.
- Focus rings for keyboards are Flutter's defaults, because the app is touch-first.
- The goal rows keep an editable number field between − and +, so a goal can be typed.
- The Scale bar hides on the Add Meal tab, which already has the live weight and Capture as its whole screen.
- A locked digit is 0.66 em wide, not the design system's 0.62: Thmanyah Sans Bold's 0 has a 0.696 em advance and would touch its neighbor.
- The Home card keeps sugar as a fourth bar beside protein, carbs and fat, so no nutrient is lost from the day's view.
- The logo is Abdullah's bowl and star, with the wordmark "Miqdar" (2026-11-07). The source files and how to rebuild the
  vectors are in `mobile/assets/branding/logo/`; the app paints it from `MiqdarMarkPainter` and `MiqdarWordmarkPainter`
  in `mobile/lib/ui/widgets/miqdar_logo.dart`. Bowl and wordmark are `ink`, the star is `logoGreen`, never `primary`.
- The splash and Welcome are always black, in both themes, so they follow the black launch screen with no white flash.
  They are the only screens that ignore the theme. Welcome's photo wall is the one place photos sit behind content, under a
  dark scrim.
