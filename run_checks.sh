#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$project_dir"

export PATH="/opt/homebrew/bin:$PATH"

PYTHON_CMD="python3"
if [[ -f .venv/bin/python ]]; then
  PYTHON_CMD=".venv/bin/python"
fi

$PYTHON_CMD database/scripts/build_database.py --replace
PYTHONPATH=backend $PYTHON_CMD -m unittest discover -s backend/tests -v

if command -v flutter >/dev/null 2>&1; then
  mkdir -p /tmp/miqdar_mobile_build
  cd mobile
  flutter pub get
  flutter analyze
  flutter test
else
  echo "Flutter SDK not available; Flutter analyze/test skipped."
fi
