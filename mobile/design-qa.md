# Miqdar Flutter design QA

- Source visual truth: `docs/Miqdar_All_Screens_Preview.png`
- Focused source target: `docs/Miqdar_Home_Page.png`
- Implementation screenshot: unavailable
- Intended viewport: 390 × 844 logical pixels
- Source pixels: 780 × 1688 (2× density)
- Intended implementation capture: 390 × 844 at device pixel ratio 2
- State: signed-in home dashboard, scale online

**Findings**

- [P0] Rendered Flutter evidence is unavailable.
  - Location: complete mobile implementation.
  - Evidence: the source visuals were opened and inspected, but the current execution environment does not contain the Flutter or Dart SDK, so the app could not be rendered or captured.
  - Impact: typography, runtime wrapping, platform chrome, and exact spacing cannot be visually certified in this environment.
  - Fix: run `./tool/bootstrap_flutter.sh`, launch an iPhone or Pixel emulator at the intended viewport, and capture the home plus each core state.

**Required fidelity surfaces**

- Fonts and typography: implemented with the same heavy rounded hierarchy using the platform-safe Arial fallback; browser/device evidence is still required.
- Spacing and layout rhythm: 22-pixel page insets, 18–24-pixel cards, and rounded green surfaces follow the source; runtime evidence is still required.
- Colors and visual tokens: the source green, dark green, pale green, warning orange, danger red, and blue macro accents are mapped in `lib/theme.dart`.
- Image quality and asset fidelity: the provided Miqdar logo and food photograph are used as raster assets; no placeholder image boxes are used.
- Copy and content: the 14-screen labels and core Miqdar product terminology are represented, with dynamic nutrition values where the Figma mock used fixed examples.

**Full-view comparison evidence**

- Source home and full 14-screen preview were inspected at original resolution.
- No implementation capture is available, so a combined source-versus-rendered comparison could not be produced.

**Focused region comparison evidence**

- Not completed because no rendered implementation image is available.

**Primary interactions prepared for testing**

- Sign-in and account creation navigation
- Scale pairing and skip flow
- Camera/gallery scan with interrupted-pick recovery
- Offline/API recognition and weight-scaled nutrition
- Health-alert evaluation and 4-second SLO display
- Save, edit, and delete meal
- 7-, 30-, and 90-day history
- Trends, goals, alerts, profile, and device settings

**Console errors checked**

- Not available without a Flutter runtime.

**Implementation checklist**

- Install a current stable Flutter SDK.
- Run the bootstrap, analyze, and test commands.
- Capture the app at the matching logical size and state.
- Compare the source and implementation in one composite image.
- Resolve any P1/P2 typography, wrapping, or spacing differences before release.

**Comparison history**

- Pass 1: blocked before rendered comparison because Flutter is unavailable.

final result: blocked
