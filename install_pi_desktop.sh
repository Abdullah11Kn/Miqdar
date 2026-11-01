#!/usr/bin/env bash
# ==============================================================================
# Miqdar - Raspberry Pi setup. Safe to run again after every git pull.
# Installs what the scale needs and makes the scale start at boot, and adds desktop icons.
# No Gemini key is needed here: the scale sends its photo to the phone app, which calls Gemini.
# ==============================================================================
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$project_dir"
chmod +x start_all.sh start_scale_app.sh start_cloudflare_tunnel.sh install_pi_desktop.sh

echo "[1/4] System packages"
if command -v apt-get >/dev/null 2>&1; then
  missing=()
  for pkg in python3-lgpio python3-picamera2 python3-pil python3-tk python3-venv curl; do
    dpkg -s "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    sudo apt-get update
    sudo apt-get install -y "${missing[@]}"
  fi
  if ! command -v cloudflared >/dev/null 2>&1; then
    case "$(uname -m)" in
      aarch64|arm64) cf_arch="arm64" ;;
      armv7l|armhf) cf_arch="arm" ;;
      *) cf_arch="amd64" ;;
    esac
    cf_deb="$(mktemp --suffix=.deb)"
    curl -L --fail -o "$cf_deb" "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${cf_arch}.deb"
    sudo dpkg -i "$cf_deb"
    rm -f "$cf_deb"
  fi
else
  echo "      apt-get not found, skipping (not a Raspberry Pi?)"
fi

echo "[2/4] Python environment"
# Plain virtualenvs cannot see the apt-installed lgpio and picamera2, which is what
# used to push a real scale into simulation mode.
if [[ ! -f .venv/pyvenv.cfg ]] || ! grep -q "include-system-site-packages = true" .venv/pyvenv.cfg; then
  rm -rf .venv
  python3 -m venv --system-site-packages .venv
fi
.venv/bin/python -c "import PIL" 2>/dev/null || .venv/bin/python -m pip install --quiet -r backend/requirements.txt

echo "[3/4] Nutrition database"
[[ -f database/miqdar_nutrition.db ]] || .venv/bin/python database/scripts/build_database.py

echo "[4/4] Desktop icons and start at boot"
desktop_dir="$(xdg-user-dir DESKTOP 2>/dev/null || true)"
[[ -n "$desktop_dir" ]] || desktop_dir="$HOME/Desktop"
mkdir -p "$desktop_dir" "$HOME/.local/share/applications"

write_icon() {  # file, name, comment, start_all arguments
  cat > "$1" <<EOF
[Desktop Entry]
Type=Application
Version=1.0
Name=$2
Comment=$3
Exec=bash -c 'cd "$project_dir" && ./start_all.sh $4'
Path=$project_dir
Icon=$project_dir/mobile/assets/branding/miqdar-logo.png
Terminal=true
Categories=Utility;
EOF
  chmod +x "$1"
}

entry="$HOME/.local/share/applications/miqdar-scale.desktop"
write_icon "$entry" "Miqdar Scale" "Start the scale, camera and API on this Wi-Fi" ""
cp "$entry" "$desktop_dir/Miqdar Scale.desktop"
write_icon "$desktop_dir/Miqdar Scale + Internet.desktop" "Miqdar Scale + Internet" \
  "Also open a public address. Anyone with it can reach the camera" "--tunnel"
for icon in "Miqdar Scale" "Miqdar Scale + Internet"; do
  chmod +x "$desktop_dir/$icon.desktop"
  command -v gio >/dev/null 2>&1 && gio set "$desktop_dir/$icon.desktop" metadata::trusted true 2>/dev/null || true
done

# Start at boot, without the tunnel. Delete this file to stop that.
mkdir -p "$HOME/.config/autostart"
cp "$entry" "$HOME/.config/autostart/miqdar-scale.desktop"

# One tap on the touchscreen starts it, with no "Execute / Open" question from the file manager.
libfm_conf="$HOME/.config/libfm/libfm.conf"
mkdir -p "$(dirname "$libfm_conf")"
[[ -f "$libfm_conf" ]] || printf '[config]\n' > "$libfm_conf"
for setting in quick_exec single_click; do
  if grep -q "^${setting}=" "$libfm_conf"; then
    sed -i.bak "s/^${setting}=.*/${setting}=1/" "$libfm_conf" && rm -f "$libfm_conf.bak"
  else
    sed -i.bak "/^\[config\]/a\\
${setting}=1
" "$libfm_conf" && rm -f "$libfm_conf.bak"
  fi
done
command -v pcmanfm >/dev/null 2>&1 && pcmanfm --reconfigure 2>/dev/null || true

echo ""
echo "Done. The scale now starts at boot. Keep the plate empty while it starts, because start-up zeroes it."
echo "Desktop icons: 'Miqdar Scale', and 'Miqdar Scale + Internet' for a public address."
if [[ ! -f scale_calibration.json ]]; then
  echo "The first start will ask you to calibrate, so keep a known weight nearby."
fi
