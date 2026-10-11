#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$project_dir"

python3 database/scripts/build_database.py --replace
PYTHONPATH=backend python3 -m unittest discover -s backend/tests -v

if command -v flutter >/dev/null 2>&1; then
  cd mobile
  flutter pub get
  flutter analyze
  flutter test
else
  echo "Flutter SDK not available; Flutter analyze/test skipped."
fi
