# Flutter REST connection

Run the app with the server URL and optional prototype token:

```bash
flutter run \
  --dart-define=MIQDAR_API_URL=http://10.0.2.2:8080 \
  --dart-define=MIQDAR_API_TOKEN=your_local_demo_token
```

`10.0.2.2` is the Android emulator route to the development computer. A physical phone must use the computer's reachable LAN IP. The app calls:

- `GET /health`
- `POST /recognize`
- `PUT /health-profile`
- `POST /recommendations`

The full-stack bundle contains the server, database, all remaining routes, and Gemini setup instructions. Recognition falls back to a clearly labelled offline demonstration when the server cannot be reached. Production deployment must use HTTPS and proper user authentication.
