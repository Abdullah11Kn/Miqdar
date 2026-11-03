# Miqdar design system

The app follows the Miqdar design system Abdullah made in a design tool on 2026-11-03:
a private design file. That link is private to him. This page holds what an agent needs
when changing the app. If the design system changes, update `mobile/lib/theme.dart` and this page.

## In the code

| What | Where |
|---|---|
| Colors, for light and dark | `MiqdarTokens` in `mobile/lib/theme.dart`. Use `context.mq.primary`, never a color value in a screen |
| Text styles | `MiqdarType` in `mobile/lib/theme.dart` |
| Icons | `MiqdarIcons` in `mobile/lib/miqdar_icons.dart`. To add one, see `mobile/assets/fonts/README.md` |
| Shared components | `mobile/lib/ui/widgets/charts_and_gauges.dart` |
| Button styles | `FilledButton` is primary, `FilledButton.tonal` is secondary, `OutlinedButton` is outline, `TextButton` is text |

## Rules

**Honest numbers**
- Always show where values came from (`AiVerificationBadge`). Gemini results are estimates, never "verified".
- A nutrient nobody knows reads **Unknown**, never 0.
- Wherever a weight appears, make the scale's state clear with its words: connected, not connected, weight sensor not
  responding, or simulated (`ScaleStatusLabel`). Never show a battery level.

**Actions**
- One main action per screen: a single `FilledButton`, usually 58 px tall. Everything else is secondary, outline or text.
- Destructive actions are `danger` text or outlines, never filled red, except the final confirm in a delete dialog.
- When Gemini is down or out of quota, Search and Manual entry stay one tap away.

**Color**
- Screens sit on `bg`, content on `surface` cards, recessed parts on `surfaceSunken`.
- `primary` is the only action color. Text on it is `onPrimary`: white in light, deep green in dark.
- Never put green on green. A selected item is solid `primary` with `onPrimary` content (chips, selected tab), or raised
  `surface` with `ink` (segments). `primarySoft` is only for a large quiet area with `ink` text.
- The hero gradient appears twice only: the Home scale card and the Profile header. It is the only gradient, apart from
  dark scrims that keep labels readable over photos.
- `accent` (orange) means "look at this", not an error: over a goal, scale not connected, low confidence, Unknown. On light
  backgrounds use `accentInk` for its text and small icons.
- `danger` is for destructive actions and failures. `info` is for neutral notices and hand-entered values.
- Each nutrient owns a mark color (`nProtein` and so on) for dots, bars and charts. Nutrient names and values stay `ink`.

**Type**
- The system font. Weights 400, 600 and 700 only, plus 500 for `caption`. No custom text font.
- One `titleScreen` per screen. Numbers use tabular figures and stay left to right in Arabic.

**Shape**
- Cards 22 px radius, buttons, fields and tiles 16, steppers 10, sheets 28 on the top corners, pills and chips full.
- Screen margins and main card padding 20 px, between cards 12, before a section heading 24.
- Cards have a 1 px border and a soft shadow in light; in dark the border does the work.
- Touch targets never go below 40 px.

**Language**
- Every screen mirrors in Arabic and works in dark mode. Leave room for longer Arabic text; do not fix button or tab widths.
- Plain, friendly, second person. No exclamation marks or emoji. Title Case for buttons, tabs and screen titles in English;
  sentence case elsewhere.
- One name per screen across its tab and title.

**Do not**
- Bring back the rejected date-brown, laban and saffron look or serif numbers.
- Add sign-in, pairing, sync or battery screens, or invent numbers.
- Use `phosphor_flutter`, which does not build on this Flutter version.
- Use colored left-border cards or illustrations of food. Food photos are real photos.

## Differences from the design system

- Text fields keep Flutter's label on the outline, not a separate label above the field.
- Focus rings for keyboards are Flutter's defaults, because the app is touch-first.
- The goal rows keep an editable number field between − and +, so a goal can be typed.
- There is no logo yet. The name is set in type, with a scale icon on a dark green square on Splash and Welcome.
