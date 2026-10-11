# Miqdar 1.1 enhancement summary

## Added

- Direct Gemini REST image recognition using `gemini-3.1-flash-lite` by default.
- Structured candidate-label output; Gemini output is never used as nutrition data.
- `GET` and `PUT /health-profile` endpoints.
- `POST /recommendations` with transparent scoring from health considerations, exclusions, daily targets, and 14-day meal history.
- Flutter meal-suggestion screen, health profile controls, explanations, offline indicator, and home-page recommendations.
- Local persistence for health considerations and dietary exclusions.
- Optional REST bearer-token protection through `MIQDAR_API_TOKEN`.
- Server health response showing the active recognition provider and model.
- Backend tests for Gemini response parsing, health-profile persistence, and recommendation behavior.

## Corrected

- User IDs are now respected by history, goals, alerts, meal-saving, and recommendation routes instead of being forced to the demo user inside each handler.
- Network fallback is visible in the Flutter UI instead of silently appearing to be an online AI result.
- Invalid recognition-provider configuration fails clearly at startup.
- The local mobile database upgrades safely from schema version 1 to 2.
- API request size is capped to prevent unbounded JSON/image payloads.

## Verification

- The regenerated database passes integrity and provenance checks.
- All eight Python tests pass.
- REST smoke tests cover health, profile update, meal recommendation, food recognition, and optional bearer-token rejection/acceptance.
- Flutter source tests are included, but Flutter analyze/test must be run on a computer with the Flutter SDK because the build SDK is not installed in this workspace.
