#!/usr/bin/env bash
set -euo pipefail

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter is required: https://docs.flutter.dev/get-started/install"
  exit 1
fi

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_dir"
flutter create --org sa.edu.kfu --project-name miqdar_mobile --platforms android,ios .
python3 tool/configure_platforms.py
flutter pub get
flutter analyze
flutter test

echo "Run Android emulator: flutter run --dart-define=MIQDAR_API_URL=http://10.0.2.2:8080"
