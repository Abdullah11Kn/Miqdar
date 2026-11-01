#!/usr/bin/env bash
# ==============================================================================
# Miqdar - start the app on the iOS simulator, on your Mac.
#   ./run_simulator.sh                         connect to the scale on this Wi-Fi
#   ./run_simulator.sh http://127.0.0.1:8080   connect to a simulated scale on this Mac
#   ./run_simulator.sh https://xxx.trycloudflare.com    or the address on the scale screen
#
# Reads GEMINI_API_KEY from .env, which git ignores, and builds it into this local
# app build. Never distribute a build made this way: the key can be extracted from it.
# ==============================================================================
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
scale_url="${1:-http://foodscale.local:8080}"
device="${MIQDAR_SIMULATOR:-iPhone 16 Pro}"

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

xcrun simctl boot "$device" 2>/dev/null || true
open -a Simulator
cd "$project_dir/mobile"
flutter run -d "$device" --dart-define-from-file="$defines"
