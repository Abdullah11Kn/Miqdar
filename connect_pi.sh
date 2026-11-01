#!/usr/bin/env bash
# ==============================================================================
# Miqdar - run ON THE MAC to open a terminal on the Raspberry Pi over the USB-C cable.
#   ./connect_pi.sh [pi-username]     default username: foodscale
#
# The first run asks for the Pi's password once, then installs a key so it never asks
# again. Afterwards plain "ssh miqdar-pi" works too, as does VS Code Remote-SSH.
# Needs ./enable_usb_ssh_pi.sh to have been run once on the Pi.
# ==============================================================================
set -euo pipefail

pi_address="192.168.7.1"
pi_user="${1:-foodscale}"
key="$HOME/.ssh/miqdar_pi_ed25519"
ssh_config="$HOME/.ssh/config"

explain_failure() {
  echo "[!] The Pi is not answering at $pi_address."
  if ifconfig | grep -q 'inet 192\.168\.7\.'; then
    echo "    The cable network is up, but SSH is not responding. The Pi may still be booting:"
    echo "    wait 30 seconds and try again."
  elif system_profiler SPUSBHostDataType SPUSBDataType 2>/dev/null | grep -q -i -E 'gadget|rndis|cdc'; then
    echo "    The Mac sees the Pi on USB but has no address yet. Wait 30 seconds and try again,"
    echo "    and check System Settings > Network for 'RNDIS/Ethernet Gadget'."
  else
    echo "    The Mac does not see the Pi on USB. Check, in order:"
    echo "    1. On the Pi, ./enable_usb_ssh_pi.sh has been run and the Pi has rebooted."
    echo "    2. If the Mac asked to 'Allow accessory to connect', click Allow."
    echo "    3. The cable carries data, not only charging, and sits in the Pi's USB-C port."
  fi
  exit 1
}

nc -z -G 3 "$pi_address" 22 2>/dev/null || explain_failure

if [[ ! -f "$key" ]]; then
  ssh-keygen -t ed25519 -f "$key" -N "" -C "miqdar-pi-usb" -q
fi

ssh_options=(-i "$key" -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5)
if ! ssh "${ssh_options[@]}" -o BatchMode=yes "$pi_user@$pi_address" true 2>/dev/null; then
  echo "First connection: enter the password of '$pi_user' on the Pi."
  ssh "${ssh_options[@]}" "$pi_user@$pi_address" \
    'mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys' < "$key.pub"
fi

if ! grep -q '^Host miqdar-pi$' "$ssh_config" 2>/dev/null; then
  cat >> "$ssh_config" <<EOF

Host miqdar-pi
  HostName $pi_address
  User $pi_user
  IdentityFile $key
  IdentitiesOnly yes
  StrictHostKeyChecking accept-new
  ServerAliveInterval 15
EOF
  chmod 600 "$ssh_config"
fi

exec ssh "${ssh_options[@]}" "$pi_user@$pi_address"
