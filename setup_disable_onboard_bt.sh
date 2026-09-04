#!/usr/bin/env bash

set -euo pipefail

if [ "$EUID" -ne 0 ]; then
  echo -e "\e[31m[ERROR]\e[0m Please run as root (sudo ./setup_disable_onboard_bt.sh)"
  exit 1
fi

UDEV_RULE_PATH="/etc/udev/rules.d/81-ignore-onboard-realtek-bt.rules"

echo "================================================="
echo " Disable Onboard Realtek BT (Keep External BT)  "
echo "================================================="

# Detect Realtek Bluetooth USB device
echo "[1/2] Identifying onboard Realtek Bluetooth..."
RTK_BT_USB=$(lsusb | grep -i "Realtek" | grep -i -E "Bluetooth|Radio" || true)

if [ -n "$RTK_BT_USB" ]; then
    DEVICE_ID=$(echo "$RTK_BT_USB" | grep -oP '[0-9a-fA-F]{4}:[0-9a-fA-F]{4}')
    VENDOR_ID=$(echo "$DEVICE_ID" | cut -d: -f1)
    PRODUCT_ID=$(echo "$DEVICE_ID" | cut -d: -f2)
    echo -e "\e[32m[INFO]\e[0m Found onboard Bluetooth: Vendor=$VENDOR_ID, Product=$PRODUCT_ID"
else
    # Fallback to standard Realtek USB Vendor ID and common B850I product IDs
    VENDOR_ID="0bda"
    PRODUCT_ID="*"
    echo -e "\e[33m[WARN]\e[0m Could not dynamically match device line. Targeting Realtek BT USB vendor ID ($VENDOR_ID)."
fi

# Create udev rule specifically unauthorizing the onboard USB device ID
echo "[2/2] Writing targeted udev rule to $UDEV_RULE_PATH..."

if [ "$PRODUCT_ID" = "*" ]; then
cat <<EOF > "$UDEV_RULE_PATH"
# Disable onboard Realtek Bluetooth USB module at driver match level
# Does NOT affect PCIe LAN, PCIe Wi-Fi, or non-Realtek external Bluetooth adapters
SUBSYSTEM=="usb", ATTR{idVendor}=="$VENDOR_ID", DRIVER=="btusb", ATTR{authorized}="0"
EOF
else
cat <<EOF > "$UDEV_RULE_PATH"
# Disable onboard Realtek Bluetooth USB module at driver match level
# Does NOT affect PCIe LAN, PCIe Wi-Fi, or non-Realtek external Bluetooth adapters
SUBSYSTEM=="usb", ATTR{idVendor}=="$VENDOR_ID", ATTR{idProduct}=="$PRODUCT_ID", ATTR{authorized}="0"
EOF
fi

# Apply the rules
udevadm control --reload-rules
udevadm trigger --subsystem-match=usb

echo "-------------------------------------------------"
echo -e "\e[32m[SUCCESS]\e[0m Onboard Realtek Bluetooth disabled."
echo "You can now plug in your new Bluetooth adapter."
echo "-------------------------------------------------"
