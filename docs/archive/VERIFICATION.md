# Verification record

Verified in the build workspace on 2026-08-30 UTC.

## Automated backend/database checks

| Check | Result |
|---|---|
| SQLite integrity | Passed (`ok`) |
| Food-to-source foreign keys | Passed |
| Queryable history | Passed (90 entries across 90 distinct days in the API window; 91 days seeded) |
| Alert evaluation after recognition | Passed (well below 4,000 ms in local test) |
| Candidate maps to predefined food | Passed |
| Sequential image + weight detection | Passed |
| SFDA product kept nutrition-pending | Passed |
| Live `/health` API smoke test | Passed |
| Live `/history?days=90` API smoke test | Passed (90 items) |
| Live `/recognize` API smoke test | Passed (Medjool dates; verified source; alert SLO met) |

Run all available checks with `./run_checks.sh`.

## Flutter verification boundary

The workspace did not have `flutter` or `dart`, so no claim is made that an APK/IPA was compiled here. `mobile/tool/bootstrap_flutter.sh` creates the standard Android/iOS wrappers, resolves packages, runs `flutter analyze`, and runs the included Flutter tests on a machine with the SDK.
