#!/usr/bin/env bash
# ==============================================================================
# Miqdar Smart Balance - Cloudflare Tunnel Launcher
# Exposes the local balance REST API (port 8080) to the internet securely,
# allowing the mobile app simulator or physical phone to connect anywhere.
# ==============================================================================
set -eo pipefail

PORT="${1:-8080}"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
URL_FILE="$PROJECT_DIR/tunnel_url.txt"
LOG_FILE="/tmp/cloudflared_miqdar.log"

echo "======================================================================"
echo "      MIQDAR BALANCE - CLOUDFLARE INTERNET TUNNEL LAUNCHER"
echo "======================================================================"

# 1. Check if cloudflared is installed
if ! command -v cloudflared >/dev/null 2>&1; then
  echo "[-] 'cloudflared' is not installed."
  ARCH="$(uname -m)"
  OS="$(uname -s)"

  if [[ "$OS" == "Darwin" ]]; then
    echo "[*] Detected macOS. Installing cloudflared via Homebrew..."
    if command -v brew >/dev/null 2>&1; then
      brew install cloudflared
    else
      echo "[!] Homebrew not found. Please install cloudflared: brew install cloudflared"
      exit 1
    fi
  elif [[ "$OS" == "Linux" ]]; then
    echo "[*] Detected Linux ($ARCH). Installing official cloudflared package..."
    TEMP_DEB="/tmp/cloudflared.deb"
    if [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
      PKG_URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64.deb"
    elif [[ "$ARCH" == "armv7l" || "$ARCH" == "armhf" ]]; then
      PKG_URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm.deb"
    else
      PKG_URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb"
    fi

    echo "[*] Downloading: $PKG_URL"
    curl -L --fail -o "$TEMP_DEB" "$PKG_URL"
    echo "[*] Installing package (requires sudo)..."
    sudo dpkg -i "$TEMP_DEB" || sudo apt-get install -f -y
    rm -f "$TEMP_DEB"
  else
    echo "[!] Unsupported OS ($OS). Please install cloudflared manually: https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/"
    exit 1
  fi
fi

echo "[✓] cloudflared is ready: $(cloudflared --version | head -n 1)"
echo "[*] Launching Cloudflare Tunnel for balance API at http://127.0.0.1:${PORT}..."

# Clean old log
rm -f "$LOG_FILE" "$URL_FILE"

# Start cloudflared in background and stream output to log
cloudflared tunnel --url "http://127.0.0.1:${PORT}" --no-autoupdate > "$LOG_FILE" 2>&1 &
TUNNEL_PID=$!

cleanup() {
  echo ""
  echo "[*] Shutting down Cloudflare Tunnel (PID: $TUNNEL_PID)..."
  kill "$TUNNEL_PID" 2>/dev/null || true
  rm -f "$URL_FILE"
  echo "[✓] Tunnel closed."
  exit 0
}
trap cleanup SIGINT SIGTERM EXIT

# Wait for tunnel URL to appear in log
echo "[*] Waiting for public HTTPS URL from Cloudflare edge network..."
TUNNEL_URL=""
for i in {1..30}; do
  if [[ -f "$LOG_FILE" ]]; then
    TUNNEL_URL="$(grep -o 'https://[a-zA-Z0-9-]*\.trycloudflare\.com' "$LOG_FILE" | head -n 1 || true)"
    if [[ -n "$TUNNEL_URL" ]]; then
      break
    fi
  fi
  sleep 1
done

if [[ -z "$TUNNEL_URL" ]]; then
  echo "[!] Failed to extract tunnel URL within 30 seconds. Tunnel log:"
  cat "$LOG_FILE"
  exit 1
fi

# Save URL for app and scripts to read
echo "$TUNNEL_URL" > "$URL_FILE"

echo ""
echo "======================================================================"
echo " 🎉 CLOUDFLARE TUNNEL IS ACTIVE AND REACHABLE FROM THE INTERNET!"
echo "======================================================================"
echo ""
echo " 👉 Public Balance API URL:"
echo "    $TUNNEL_URL"
echo ""
echo " 📱 HOW TO CONNECT YOUR MOBILE SIMULATOR / PHYSICAL PHONE:"
echo "    1. Open the Miqdar app on your simulator or phone."
echo "    2. Go to Profile / Device Settings -> Tap 'Set API Server URL'."
echo "    3. Paste or type the URL above:"
echo "       $TUNNEL_URL"
echo "    4. Tap 'Save & Connect'. The app will instantly connect to your balance!"
echo ""
echo " URL saved to: $URL_FILE"
echo " Press Ctrl+C at any time to stop the tunnel."
echo "======================================================================"

# Keep running until interrupted
wait "$TUNNEL_PID"
