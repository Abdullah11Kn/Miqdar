# Miqdar Flutter mobile app

This project implements the 14-screen Miqdar Figma flow as a functional Flutter app for Android and iOS.

## Included product flows

- Splash, sign-in, account creation, and smart-scale pairing
- Home dashboard with measured daily nutrition progress
- Camera/gallery food scan with an offline demo image fallback
- AI recognition result, confidence, provenance, and weight-scaled nutrients
- Health-threshold evaluation immediately after recognition, measured against the 4-second requirement
- Editable meal details and persistent local SQLite storage
- 7-, 30-, and 90-day history, trend chart, and macro-balance chart
- Goals and alert thresholds for calories, sugar, sodium, potassium, carbohydrates, and protein
- Alerts, profile, connected-device settings, and notification preferences
- Meal suggestions based on selected health considerations, exclusions, configured targets, and the previous 14 days of meals
- Optional connection to the Miqdar backend through `MIQDAR_API_URL`

## First run

Install Flutter 3.24 or newer, then run:

```bash
./tool/bootstrap_flutter.sh
flutter run --dart-define=MIQDAR_API_URL=http://10.0.2.2:8080
```

When the server has `MIQDAR_API_TOKEN` enabled, add `--dart-define=MIQDAR_API_TOKEN=your-local-token` to the run command. Do not commit the token.

The bootstrap command generates the standard Android/iOS wrappers, adds camera and gallery permissions, installs packages, analyzes the source, and runs the tests. `10.0.2.2` is the Android emulator address for a backend running on the development computer.

If the API is not available, recognition uses deterministic local nutrition profiles so every presentation flow still works. The local database seeds a complete 90-day demonstration history on first launch.

The header clearly shows whether the app is connected to the REST API or using offline demonstration mode. Meal suggestions also carry an `Offline` label when they were calculated locally.

## Presentation demo path

1. Sign in with the prefilled demonstration account.
2. Pair `Miqdar-015`, or choose **I’ll do this later**.
3. Open **Scan**, leave the Medjool dates hint selected, and tap **Recognize food**.
4. Show the recognition confidence, official-record badge, nutrition grid, and measured alert time.
5. Save the meal, then open **History**, **Trends**, and **Alerts**.
6. Open **Meal ideas for you**, select health considerations or exclusions, and show how the explanations and ranking change.

The thresholds and meal suggestions are prototype planning support and not medical recommendations.
