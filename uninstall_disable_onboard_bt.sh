#!/usr/bin/env bash
set -euo pipefail

if [[ "$EUID" -ne 0 ]]; then
    echo -e "\e[31m[ERROR]\e[0m Please run as root:"
    echo "sudo ./uninstall_disable_onboard_bt.sh"
    exit 1
fi

UDEV_RULE_PATH="/etc/udev/rules.d/81-ignore-onboard-realtek-bt.rules"

echo "================================================="
echo " Restore Onboard Realtek Bluetooth"
echo "================================================="

if [[ ! -f "$UDEV_RULE_PATH" ]]; then
    echo "[INFO] Rule file is not present."
    exit 0
fi

# Read the IDs from the actual rule before deleting it.
VENDOR_ID="$(
    sed -n 's/.*ATTR{idVendor}=="\([^"]*\)".*/\1/p' \
        "$UDEV_RULE_PATH" | head -n1
)"

PRODUCT_ID="$(
    sed -n 's/.*ATTR{idProduct}=="\([^"]*\)".*/\1/p' \
        "$UDEV_RULE_PATH" | head -n1
)"

echo "[1/3] Removing:"
echo "       $UDEV_RULE_PATH"

rm -f "$UDEV_RULE_PATH"

echo "[2/3] Reloading udev rules..."
udevadm control --reload-rules

echo "[3/3] Re-authorizing the disabled USB device..."

for DEVICE_PATH in /sys/bus/usb/devices/*; do
    [[ -f "$DEVICE_PATH/idVendor" ]] || continue
    [[ -f "$DEVICE_PATH/authorized" ]] || continue

    DEVICE_VENDOR="$(cat "$DEVICE_PATH/idVendor")"
    DEVICE_PRODUCT="$(cat "$DEVICE_PATH/idProduct")"

    [[ "$DEVICE_VENDOR" == "$VENDOR_ID" ]] || continue

    # The setup script may have used PRODUCT_ID="*" when detection failed.
    if [[ -n "$PRODUCT_ID" && "$PRODUCT_ID" != "*" &&
          "$DEVICE_PRODUCT" != "$PRODUCT_ID" ]]; then
        continue
    fi

    CURRENT_AUTHORIZED="$(cat "$DEVICE_PATH/authorized")"

    if [[ "$CURRENT_AUTHORIZED" == "0" ]]; then
        echo "       Re-authorizing $DEVICE_PATH"
        echo 1 > "$DEVICE_PATH/authorized"
    fi
done

# Trigger USB device processing after the rule has been removed.
udevadm trigger --subsystem-match=usb

echo "-------------------------------------------------"
echo -e "\e[32m[SUCCESS]\e[0m Onboard Bluetooth restore completed."
echo "The udev rule was removed and the matching USB device was re-authorized."
echo "A reboot may be required if Bluetooth does not immediately reappear."
echo "-------------------------------------------------"
