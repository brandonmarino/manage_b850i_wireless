#!/usr/bin/env bash
set -u

INSTALL_PATH="/usr/local/sbin/enable-bluetooth-wake"
SERVICE_NAME="enable-bluetooth-wake.service"
SERVICE_PATH="/etc/systemd/system/$SERVICE_NAME"

if [[ "$EUID" -ne 0 ]]; then
    echo "Run this script with sudo:"
    echo "  sudo bash $0"
    exit 1
fi

disable_bluetooth_wake() {
    local hci device parent

    for hci in /sys/class/bluetooth/hci*/device; do
        [[ -e "$hci" ]] || continue

        device="$(realpath -e "$hci" 2>/dev/null || true)"
        [[ -n "$device" ]] || continue

        parent="$device"

        while [[ "$parent" != "/" && "$parent" != "/sys" ]]; do
            if [[ -f "$parent/idVendor" && -f "$parent/power/wakeup" ]]; then
                echo disabled > "$parent/power/wakeup"
                echo "Disabled wake for USB device:"
                echo "  $parent"
                break
            fi

            parent="$(dirname "$parent")"
        done
    }
}

if [[ "${1:-}" == "--disable-wake" ]]; then
    disable_bluetooth_wake
fi

echo "Stopping and disabling $SERVICE_NAME..."
systemctl disable --now "$SERVICE_NAME" 2>/dev/null || true

echo "Removing systemd service..."
rm -f "$SERVICE_PATH"

echo "Removing installed helper..."
rm -f "$INSTALL_PATH"

echo "Reloading systemd..."
systemctl daemon-reload
systemctl reset-failed "$SERVICE_NAME" 2>/dev/null || true

echo
echo "Bluetooth wake service has been uninstalled."

if [[ "${1:-}" != "--disable-wake" ]]; then
    echo
    echo "The current wake setting was not changed."
    echo "To also disable wake on currently detected Bluetooth USB adapters, run:"
    echo "  sudo bash $0 --disable-wake"
fi
