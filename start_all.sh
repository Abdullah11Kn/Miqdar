#!/usr/bin/env bash
# ==============================================================================
# Miqdar - one-click start (this is what the desktop icon runs on the Pi).
# Starts the Cloudflare tunnel in the background, then the scale fullscreen.
# The address to enter in the phone app is shown at the bottom of the scale screen.
# ==============================================================================
set -uo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$project_dir"

port="${MIQDAR_PORT:-8080}"
tunnel_log="/tmp/miqdar_tunnel_launcher.log"
tunnel_pid=""

pause_on_error() {
  echo ""
  read -r -p "Press Enter to close this window. " _ || true
}

stop_tunnel() {
  if [[ -n "$tunnel_pid" ]]; then
    kill "$tunnel_pid" 2>/dev/null || true
  fi
}
trap stop_tunnel EXIT

# Clicking the icon twice must not fight over the GPIO pins and camera
pkill -f "$project_dir/start_cloudflare_tunnel.sh" 2>/dev/null || true
pkill -f "cloudflared tunnel --url http://127.0.0.1:${port}" 2>/dev/null || true
pkill -f "app.py --fullscreen" 2>/dev/null || true
sleep 1

python_cmd="python3"
[[ -x .venv/bin/python ]] && python_cmd=".venv/bin/python"

if [[ ! -f scale_calibration.json ]]; then
  echo "This scale has not been calibrated yet. You need a known weight for this one-time step."
  "$python_cmd" scale.py calibrate || { pause_on_error; exit 1; }
fi

rm -f tunnel_url.txt
if command -v cloudflared >/dev/null 2>&1; then
  "$project_dir/start_cloudflare_tunnel.sh" "$port" >"$tunnel_log" 2>&1 &
  tunnel_pid=$!
  echo "[*] Tunnel starting in the background (log: $tunnel_log)"
else
  echo "[!] cloudflared is not installed: the app can only connect over the same Wi-Fi."
fi

./start_scale_app.sh --fullscreen --port "$port"
status=$?
if [[ $status -ne 0 ]]; then
  echo "[!] The scale stopped with an error (code $status). See the message above."
  pause_on_error
fi
exit "$status"
