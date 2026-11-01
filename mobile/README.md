# Miqdar Flutter app

Tabs: Home, Add Meal, Diary, Insights, Profile. In English and Arabic, light and dark. The diary is stored on the phone.
There are no accounts. A demo with sample data is available from the welcome screen and is never saved.

From the project root, `./run_simulator.sh` runs the app against the real scale with the key from `.env`.

```bash
flutter analyze && flutter test
# End-to-end flow, on a THROWAWAY simulator because this wipes its app data:
../start_scale_app.sh --headless --mock --auto-capture     # in another terminal
flutter test integration_test/scale_flow_test.dart -d <simulator id> --dart-define=GEMINI_API_KEY=<key>
```

Where things are, and the project rules: [AGENTS.md](../AGENTS.md).
