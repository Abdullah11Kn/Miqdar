# Miqdar brand and design

Miqdar (مقدار) means "measure". The brand is a precise instrument in a Saudi kitchen, not a green health app.

## The idea: the dial

One shape carries the whole brand: **a ring that is both a plate seen from above and a scale's dial.**
Everything measured is drawn on it: the calorie goal on Home, the live weight on Add Meal, the photo while Gemini reads
it, the welcome screen. Use `MeasureDial` in `mobile/lib/ui/widgets/brand.dart`. Do not add other kinds of gauge.

## Logo

The Arabic letter **م** inside a dial that is three quarters measured (`MiqdarMark`). The wordmark sets
"Miqdar | مقدار" side by side (`MiqdarWordmark`). App icons are generated from the same drawing: saffron arc and laban
letter on date-brown.

## Color

Named after the kitchen. Tokens are in `mobile/lib/theme.dart`; use `Miq.of(context)` for anything that changes in dark mode.

| Token | Hex | Use |
|---|---|---|
| Tamr, `ink` | `#20160F` | Text, dark panels, the welcome and analyzing screens |
| Laban, `paper` | `#F6F1E7` | Page background |
| `cream` | `#FFFCF6` | Cards |
| Za'faran, `saffron` | `#E8861A` | The accent: main buttons and dial. Always with ink text on it, never white |
| `saffronDeep` | `#B85F08` | Saffron as text on paper, where plain saffron is too faint |

Nutrients: protein pomegranate `#A92B38`, carbs turmeric `#D9A321`, fat olive `#6E7F35`, sugar rose `#C55A7B`, fiber
cardamom `#3F7C58`, sodium gulf `#2B7780`, potassium aubergine `#6A4A7C`.

Use saffron for one main thing per screen. Dark mode is warm near-black (`#14100C`), never pure black or grey.

## Type

| Role | Font | Where |
|---|---|---|
| Display | Instrument Serif, with Amiri for Arabic (`MiqType.display`) | Numbers, food names, titles |
| Everything else | IBM Plex Sans Arabic (`Plex`), Arabic and Latin | Labels, body, buttons |

Numbers are the heroes: set them large in the serif, with the unit smaller beside them. Display type has one weight;
never fake bold on it. Text weights stop at 600.

## Icons

Phosphor Light through `MiqIcons`, with Fill for a selected tab. Chevrons and back arrows stay Material because those mirror in Arabic.

## Layout

- Hairlines, not shadows. Rows sit on one sheet with lines between them (`Ledger`, `LedgerRow`).
- Buttons are pills; the main action fills the width.
- One dark panel at most on a light page (the scale panel on Home).
- Food photos are the only imagery, cut to circles in lists and on dials, edge to edge on Review.

## Fonts and licences

All bundled in `mobile/assets/fonts/` with their licence files: IBM Plex Sans Arabic, Instrument Serif and Amiri (SIL OFL),
Phosphor (MIT). The `phosphor_flutter` package is deliberately not used because it does not build on current Flutter.
