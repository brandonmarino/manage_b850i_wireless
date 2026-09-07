#!/usr/bin/env bash
set -euo pipefail

SERVICE_NAME="enable-bt-wake.service"
SERVICE_PATH="/etc/systemd/system/$SERVICE_NAME"
INSTALL_DIR="/var/lib/bt-wake"
INSTALL_PATH="$INSTALL_DIR/enable-bt-wake"

# Possible location used by the original installer
OLD_INSTALL_PATH="/usr/local/sbin/enable-bt-wake"

if [[ "$EUID" -ne 0 ]]; then
    echo "Run this script with sudo:"
    echo "  sudo bash $0"
    exit 1
fi

echo "Stopping and disabling $SERVICE_NAME..."

systemctl disable --now "$SERVICE_NAME" 2>/dev/null || true

echo "Removing systemd unit..."
rm -f "$SERVICE_PATH"

echo "Removing installed helper..."
rm -f "$INSTALL_PATH"
rmdir "$INSTALL_DIR" 2>/dev/null || true

# Remove the old helper if it was installed by the original script.
rm -f "$OLD_INSTALL_PATH"

systemctl daemon-reload
systemctl reset-failed "$SERVICE_NAME" 2>/dev/null || true

echo
echo "Bluetooth wake service removed."
