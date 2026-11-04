#!/usr/bin/env bash
# ==============================================================================
# Miqdar - put the Thmanyah fonts where the app build expects them.
#
# Thmanyah's licence lets the app embed the fonts in its build, but forbids uploading or
# hosting the font files and forbids changing them. This repository is public, so the files
# are ignored by git and every Mac installs them from the official zips, unchanged:
# download them from https://font.thmanyah.com into ~/Downloads or this folder, then run this.
# ==============================================================================
set -euo pipefail

fonts_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
target="$fonts_dir/thmanyah"
mkdir -p "$target"

for family in sans serif-display serif-text; do
  zip_file=""
  for candidate in "$fonts_dir/thmanyah-$family-woff2-otf.zip" "$HOME/Downloads/thmanyah-$family-woff2-otf.zip"; do
    if [[ -f "$candidate" ]]; then
      zip_file="$candidate"
      break
    fi
  done
  if [[ -z "$zip_file" ]]; then
    echo "[!] thmanyah-$family-woff2-otf.zip not found. Download it from https://font.thmanyah.com"
    exit 1
  fi
  unzip -qojo "$zip_file" "thmanyah-$family/otf/*.otf" -d "$target"
done

echo "[OK] Thmanyah fonts are in $target"
