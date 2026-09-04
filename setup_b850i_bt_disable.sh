#!/usr/bin/env bash

set -euo pipefail

if [ "$EUID" -ne 0 ]; then
  echo -e "\e[31m[ERROR]\e[0m Please run as root (sudo ./setup_b850i_bt_disable.sh)"
  exit 1
fi

UDEV_RULE_PATH="/etc/udev/rules.d/81-disable-b850i-bluetooth.rules"

echo "================================================="
echo "   Disabling Realtek Bluetooth via Udev Rule     "
echo "================================================="

# Target the Bluetooth subsystem directly so LAN and Wi-Fi are completely untouched
cat <<EOF > "$UDEV_RULE_PATH"
# Disable Realtek Bluetooth interfaces specifically without affecting Realtek LAN/Wi-Fi
SUBSYSTEM=="bluetooth", KERNEL=="hci*", ATTR{type}=="BR/EDR", RUN+="/bin/sh -c 'echo 0 > /sys%p/rfkill*/state || true'"
SUBSYSTEM=="bluetooth", ATTR{vendor}=="0x0bda", ATTRS{idVendor}=="0bda", ATTR{authorized}="0"
EOF

# Reload udev
udevadm control --reload-rules
udevadm trigger

# Soft-block bluetooth as immediate fallback to ensure radio power-down
if command -v rfkill &> /dev/null; then
    rfkill block bluetooth || true
fi

echo -e "\e[32m[SUCCESS]\e[0m Rule written to $UDEV_RULE_PATH."
echo "Bluetooth subsystem disabled. Realtek LAN and Wi-Fi remain active."
