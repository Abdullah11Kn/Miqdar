#!/usr/bin/env bash
# ==============================================================================
# Miqdar - install the app on your own iPhone, on your Mac, to test what a simulator cannot:
# voice, the camera and reminders.
#   ./run_iphone.sh                         connect to the scale on this Wi-Fi
#   ./run_iphone.sh http://172.20.10.3:8080 or the address on the scale screen
#
# Reads GEMINI_API_KEY from .env and builds it into this app. Keep this build on your own
# phone and never distribute it: the key can be extracted from it. A profile build keeps the
# test-only Skip button and still opens without the Mac attached.
# ==============================================================================
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
scale_url="${1:-http://foodscale.local:8080}"
device="${MIQDAR_IPHONE:-iphone A}"

gemini_key="$(sed -n -E 's/^GEMINI_API_KEY=["'\'']?([^"'\'']*)["'\'']?.*$/\1/p' "$project_dir/.env" 2>/dev/null | head -n 1)"
if [[ -z "$gemini_key" || "$gemini_key" == "YOUR_API_KEY_HERE" ]]; then
  echo "[!] Put your key in $project_dir/.env as GEMINI_API_KEY=\"...\""
  exit 1
fi

# A temp file keeps the key out of the process list
defines="$(mktemp)"
trap 'rm -f "$defines"' EXIT
chmod 600 "$defines"
printf '{"GEMINI_API_KEY":"%s","MIQDAR_API_URL":"%s"}\n' "$gemini_key" "$scale_url" > "$defines"

cd "$project_dir/mobile"
flutter run --profile --no-resident -d "$device" --dart-define-from-file="$defines"
