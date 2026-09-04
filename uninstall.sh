#!/usr/bin/env bash

# Exit on error, but handle errors cleanly
set -e

# Function to display messages
log_info() {
    echo -e "\e[32m[INFO]\e[0m $1"
}

log_warn() {
    echo -e "\e[33m[WARN]\e[0m $1"
}

# Ensure script is run as root
if [ "$EUID" -ne 0 ]; then
  echo -e "\e[31m[ERROR]\e[0m Please run as root (e.g., sudo ./uninstall.sh)"
  exit 1
fi

echo "=========================================="
echo " Uninstalling B850I Wireless Management   "
echo "=========================================="

# 1. Stop and disable systemd service (if present)
SERVICE_NAME="manage_b850i_wireless.service"

if systemctl list-unit-files | grep -q "$SERVICE_NAME"; then
    log_info "Stopping and disabling $SERVICE_NAME..."
    systemctl stop "$SERVICE_NAME" || log_warn "Failed to stop $SERVICE_NAME"
    systemctl disable "$SERVICE_NAME" || log_warn "Failed to disable $SERVICE_NAME"
    
    if [ -f "/etc/systemd/system/$SERVICE_NAME" ]; then
        rm -f "/etc/systemd/system/$SERVICE_NAME"
        log_info "Removed service file: /etc/systemd/system/$SERVICE_NAME"
    fi
    
    systemctl daemon-reload
    systemctl reset-failed
else
    log_info "No systemd service found matching $SERVICE_NAME."
fi

# 2. Remove script/binary files
FILES_TO_REMOVE=(
    "/usr/local/bin/manage_b850i_wireless.sh"
    "/usr/bin/manage_b850i_wireless.sh"
    "/etc/manage_b850i_wireless.conf"
)

for file in "${FILES_TO_REMOVE[@]}"; do
    if [ -f "$file" ]; then
        rm -f "$file"
        log_info "Removed file: $file"
    fi
done

# 3. Optional: Restore default driver / module configurations if modprobe overrides were created
MODPROBE_CONF="/etc/modprobe.d/b850i_wireless.conf"
if [ -f "$MODPROBE_CONF" ]; then
    rm -f "$MODPROBE_CONF"
    log_info "Removed custom kernel module configuration: $MODPROBE_CONF"
fi

# 4. Prompt to unbind or reload default wireless drivers
log_info "Uninstallation complete!"
echo "------------------------------------------"
echo "Note: If driver modules were modified or reloaded, you may need to restart NetworkManager or reboot your system."
read -p "Would you like to restart NetworkManager now? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    systemctl restart NetworkManager && log_info "NetworkManager restarted."
fi

exit 0
