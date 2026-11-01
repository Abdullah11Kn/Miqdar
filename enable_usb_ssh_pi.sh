#!/usr/bin/env bash
# ==============================================================================
# Miqdar - run once ON THE RASPBERRY PI so a Mac can control it over the USB-C cable.
#   ./enable_usb_ssh_pi.sh          turn it on (asks to reboot)
#   ./enable_usb_ssh_pi.sh --undo   turn it off again
#
# The Pi's USB-C port becomes a small private network: the Pi is 192.168.7.1 and the
# Mac is given an address automatically. No gateway is offered, so the Mac keeps using
# its own Wi-Fi for internet, and the Pi keeps using its own.
# ==============================================================================
set -euo pipefail

PI_ADDRESS="192.168.7.1"
CONNECTION="miqdar-usb"
OVERLAY_LINE="dtoverlay=dwc2,dr_mode=peripheral"
# Fixed addresses, so the Mac treats it as the same network adapter after every reboot.
GADGET_ARGS="modules-load=dwc2,g_ether g_ether.dev_addr=02:6d:71:64:72:01 g_ether.host_addr=02:6d:71:64:72:02"
DNSMASQ_CONF="/etc/NetworkManager/dnsmasq-shared.d/miqdar-usb.conf"
SUDO="${SUDO-sudo}"

find_boot_dir() {
  if [[ -f /boot/firmware/cmdline.txt ]]; then
    echo /boot/firmware
  elif [[ -f /boot/cmdline.txt ]]; then
    echo /boot
  else
    echo "[!] Could not find cmdline.txt in /boot/firmware or /boot." >&2
    return 1
  fi
}

# Prints a kernel command line without our settings. Other modules-load entries are kept.
strip_gadget_args() {
  tr ' ' '\n' <<<"$1" | awk '
    /^g_ether\./ { next }
    /^modules-load=/ {
      split(substr($0, 14), mods, ","); kept = ""
      for (i = 1; i in mods; i++) if (mods[i] != "dwc2" && mods[i] != "g_ether") kept = kept (kept ? "," : "") mods[i]
      if (kept) print "modules-load=" kept
      next
    }
    NF { print }' | paste -s -d ' ' -
}

write_boot_file() {  # target, new content
  local temp
  temp="$(mktemp)"
  printf '%s\n' "$2" > "$temp"
  $SUDO cp "$temp" "$1"
  rm -f "$temp"
}

check_cmdline() {
  if [[ "$(grep -c '' "$1")" -ne 1 ]] || ! grep -q 'root=' "$1"; then
    echo "[!] $1 does not look like a normal one-line kernel command line. Nothing was changed." >&2
    return 1
  fi
}

enable_boot_files() {
  local boot_dir="$1" config="$1/config.txt" cmdline="$1/cmdline.txt" current config_new
  check_cmdline "$cmdline" || return 1
  for file in "$config" "$cmdline"; do
    [[ -f "$file.miqdar-backup" ]] || $SUDO cp "$file" "$file.miqdar-backup"
  done
  current="$(strip_gadget_args "$(cat "$cmdline")")"
  if [[ "$current" == *" rootwait "* ]]; then
    write_boot_file "$cmdline" "${current/ rootwait / rootwait $GADGET_ARGS }"
  else
    write_boot_file "$cmdline" "$current $GADGET_ARGS"
  fi
  config_new="$(grep -v '^dtoverlay=dwc2' "$config" || true)"
  write_boot_file "$config" "$config_new
[all]
$OVERLAY_LINE"
}

disable_boot_files() {
  local config="$1/config.txt" cmdline="$1/cmdline.txt"
  check_cmdline "$cmdline" || return 1
  write_boot_file "$cmdline" "$(strip_gadget_args "$(cat "$cmdline")")"
  write_boot_file "$config" "$(grep -v "^$OVERLAY_LINE\$" "$config" || true)"
}

enable() {
  local boot_dir
  boot_dir="$(find_boot_dir)"
  if ! systemctl is-active --quiet NetworkManager; then
    echo "[!] This needs NetworkManager (Raspberry Pi OS Bookworm or newer). Nothing was changed." >&2
    exit 1
  fi
  if ! grep -q -E 'Raspberry Pi (4|5)|Compute Module 4' /proc/device-tree/model 2>/dev/null; then
    echo "[!] Only meant for Pi 4 and 5 USB-C. This board: $(tr -d '\0' </proc/device-tree/model 2>/dev/null)" >&2
    exit 1
  fi

  echo "[1/4] Remote login (SSH)"
  $SUDO systemctl enable --now ssh

  echo "[2/4] Address server for the cable"
  dpkg -s dnsmasq-base >/dev/null 2>&1 || { $SUDO apt-get update; $SUDO apt-get install -y dnsmasq-base; }
  $SUDO mkdir -p "$(dirname "$DNSMASQ_CONF")"
  # Empty router and DNS options: the Mac must not send its internet traffic to the Pi.
  printf 'dhcp-option=3\ndhcp-option=6\n' | $SUDO tee "$DNSMASQ_CONF" >/dev/null

  echo "[3/4] USB network"
  $SUDO nmcli connection delete "$CONNECTION" >/dev/null 2>&1 || true
  $SUDO nmcli connection add type ethernet ifname usb0 con-name "$CONNECTION" \
    connection.autoconnect yes connection.autoconnect-priority 10 \
    ipv4.method shared ipv4.addresses "$PI_ADDRESS/24" ipv4.never-default yes \
    ipv6.method disabled >/dev/null

  echo "[4/4] USB-C port mode (backups: $boot_dir/*.miqdar-backup)"
  enable_boot_files "$boot_dir"

  echo ""
  echo "Done. After the reboot, on the Mac run:  ./connect_pi.sh $(id -un)"
  echo "Power right now: $(vcgencmd get_throttled 2>/dev/null || echo unknown)  (throttled=0x0 is healthy)"
  read -r -p "Reboot now? [Y/n] " answer || answer="n"
  if [[ ! "$answer" =~ ^[Nn] ]]; then
    $SUDO reboot
  else
    echo "Run 'sudo reboot' when ready. The cable will not work until then."
  fi
}

undo() {
  disable_boot_files "$(find_boot_dir)"
  $SUDO nmcli connection delete "$CONNECTION" >/dev/null 2>&1 || true
  $SUDO rm -f "$DNSMASQ_CONF"
  echo "USB network removed. SSH is still on (sudo systemctl disable --now ssh to stop it). Reboot to finish."
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  case "${1:-}" in
    --undo) undo ;;
    "") enable ;;
    *) echo "Usage: $0 [--undo]" >&2; exit 2 ;;
  esac
fi
