#!/usr/bin/env bash

# Exit immediately if a command fails
set -euo pipefail

# Ensure script is run with root privileges
if [ "$EUID" -ne 0 ]; then
  echo -e "\e[31m[ERROR]\e[0m Please run as root (e.g., sudo ./setup_b850i_udev.sh)"
  exit 1
fi

UDEV_RULE_PATH="/etc/udev/rules.d/81-disable-onboard-bluetooth.rules"

echo "================================================="
echo "   B850I Onboard Bluetooth Udev Disabler         "
echo "================================================="

# Auto-detect Realtek Bluetooth USB device IDs
echo "[1/3] Scanning for Realtek Bluetooth USB devices..."
BT_DEVICE=$(lsusb | grep -i "Realtek" | grep -i -E "Bluetooth|Radio" || true)

if [ -z "$BT_DEVICE" ]; then
    echo -e "\e[33m[WARN]\e[0m Could not auto-detect Realtek Bluetooth via 'lsusb'."
    read -p "Enter Vendor ID [default 0bda]: " VENDOR_ID
    VENDOR_ID=${VENDOR_ID:-0bda}
    read -p "Enter Product ID (e.g., b850): " PRODUCT_ID
    if [ -z "$PRODUCT_ID" ]; then
        echo -e "\e[31m[ERROR]\e[0m Product ID is required."
        exit 1
    fi
else
    # Extract ID pattern (e.g. 0bda:b850)
    DEVICE_ID=$(echo "$BT_DEVICE" | grep -oP '[0-9a-fA-F]{4}:[0-9a-fA-F]{4}')
    VENDOR_ID=$(echo "$DEVICE_ID" | cut -d: -f1)
    PRODUCT_ID=$(echo "$DEVICE_ID" | cut -d: -f2)
    echo -e "\e[32m[INFO]\e[0m Found Realtek Bluetooth Device: Vendor=$VENDOR_ID, Product=$PRODUCT_ID"
fi

# Write the isolated udev rule
echo "[2/3] Creating udev rule at $UDEV_RULE_PATH..."
cat <<EOF > "$UDEV_RULE_PATH"
# Disable onboard Realtek Bluetooth USB controller without affecting PCIe LAN/Wi-Fi
SUBSYSTEM=="usb", ATTR{idVendor}=="$VENDOR_ID", ATTR{idProduct}=="$PRODUCT_ID", ATTR{authorized}="0"
EOF

# Reload udev rules to apply immediately
echo "[3/3] Reloading system udev rules..."
udevadm control --reload-rules
udevadm trigger --subsystem-match=usb

echo "-------------------------------------------------"
echo -e "\e[32m[SUCCESS]\e[0m Udev rule created successfully."
echo "The onboard Bluetooth USB controller is now disabled."
echo "PCIe devices (Realtek LAN / Wi-Fi) remain unaffected."
echo "-------------------------------------------------"
