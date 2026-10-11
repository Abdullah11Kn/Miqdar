# Gemini server and Flutter connection

## 1. Configure the backend

From the project root:

```bash
cp backend/.env.example backend/.env
```

Edit `backend/.env`:

```text
MIQDAR_RECOGNITION_PROVIDER=gemini
GEMINI_API_KEY=your_key_from_google_ai_studio
GEMINI_MODEL=gemini-3.1-flash-lite
MIQDAR_API_TOKEN=choose_a_long_random_demo_token
```

Never commit `backend/.env`. The implementation follows Google's Gemini `generateContent` REST interface with inline image data and structured JSON output:

- https://ai.google.dev/gemini-api/docs/generate-content/image-understanding
- https://ai.google.dev/gemini-api/docs/models/gemini-3.1-flash-lite

## 2. Build and test

```bash
python3 -m pip install -r backend/requirements.txt
./run_checks.sh
```

## 3. Start the REST server

```bash
./start_server.sh
```

Default address: `http://0.0.0.0:8080`.

Check the active provider:

```bash
curl http://127.0.0.1:8080/health
```

The response should name `gemini` and `gemini-3.1-flash-lite`. A mock/offline provider is acceptable only for demonstrations and tests.

## 4. Run Flutter

Android emulator:

```bash
cd mobile
./tool/bootstrap_flutter.sh
flutter run \
  --dart-define=MIQDAR_API_URL=http://10.0.2.2:8080 \
  --dart-define=MIQDAR_API_TOKEN=the_same_demo_token
```

For a physical Android phone, replace `10.0.2.2` with the development computer's LAN IP and allow port 8080 through the local firewall. Keep the phone and computer on the same trusted network. Production must use HTTPS, real user authentication, and restricted CORS.

## 5. Main REST routes

| Method | Route | Purpose |
|---|---|---|
| GET | `/health` | Server, database, provider, and model status |
| POST | `/recognize` | Gemini food classification, database mapping, mass scaling, and alert preview |
| GET | `/history?days=90&user_id=demo-user` | Inclusive meal-history window |
| GET/PUT | `/goals` | Read or update nutrition targets |
| GET/PUT | `/health-profile` | Read or update health considerations and exclusions |
| POST | `/recommendations` | Rank database meals using goals and recent history |
| POST | `/meals` | Save a confirmed recognized meal |
| GET | `/alerts` | Read saved threshold events |

The recommendation route is not a diagnostic service. Conditions are self-declared planning inputs, and kidney-related suggestions must use clinician-approved nutrient targets.
