#!/usr/bin/env bash
# ==============================================================================
# Miqdar - copy the Thmanyah fonts from this Mac to the Pi, for the scale's touchscreen.
# Their licence forbids hosting them, so they cannot reach the Pi through git. They stay on your
# own devices and unchanged. Run install_thmanyah.sh first. Without them the screen uses DejaVu Sans.
#   ./install_thmanyah_pi.sh [ssh host, default miqdar-pi]
# ==============================================================================
set -euo pipefail

fonts_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/thmanyah"
host="${1:-miqdar-pi}"

ssh "$host" 'mkdir -p ~/.local/share/fonts/thmanyah'
scp -q "$fonts_dir"/thmanyah-sans-{Regular,Bold}.otf "$fonts_dir"/thmanyah-serif-display-Bold.otf \
  "$host:.local/share/fonts/thmanyah/"
ssh "$host" 'fc-cache -f ~/.local/share/fonts && fc-list | grep -ic thmanyah'
echo "[OK] Restart the scale so it picks up the fonts."
