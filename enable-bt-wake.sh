#!/usr/bin/env bash
set -u

INSTALL_PATH="/usr/local/sbin/enable-bluetooth-wake"
SERVICE_PATH="/etc/systemd/system/enable-bluetooth-wake.service"

if [[ "$EUID" -ne 0 ]]; then
    echo "Run this script with sudo:"
    echo "  sudo bash $0"
    exit 1
fi

enable_bluetooth_wake() {
    local found=0
    local hci device parent vendor

    # Give Bluetooth and USB devices time to appear.
    for _ in {1..20}; do
        for hci in /sys/class/bluetooth/hci*/device; do
            [[ -e "$hci" ]] || continue

            device="$(realpath -e "$hci" 2>/dev/null || true)"
            [[ -n "$device" ]] || continue

            # Walk up from the Bluetooth interface to its USB device.
            parent="$device"
            while [[ "$parent" != "/" && "$parent" != "/sys" ]]; do
                if [[ -f "$parent/idVendor" && -f "$parent/power/wakeup" ]]; then
                    vendor="$(cat "$parent/idVendor" 2>/dev/null || true)"

                    echo enabled > "$parent/power/wakeup"

                    echo "Enabled wake for:"
                    echo "  Bluetooth device: $hci"
                    echo "  USB path:         $parent"
                    echo "  USB vendor:       $vendor"
                    echo "  Wake status:      $(cat "$parent/power/wakeup")"

                    found=1
                    break
                fi

                parent="$(dirname "$parent")"
            done
        done

        [[ "$found" -eq 1 ]] && return 0
        sleep 1
    done

    echo "No Bluetooth USB adapter was found."
    echo "Make sure Bluetooth is enabled and the adapter is visible with:"
    echo "  bluetoothctl list"
    return 1
}

# When invoked by systemd, just enable wake.
if [[ "${1:-}" == "--enable" ]]; then
    enable_bluetooth_wake
    exit $?
fi

# Install this script as the persistent helper.
install -Dm755 "$0" "$INSTALL_PATH"

# Install a service that reapplies the setting after every boot.
cat > "$SERVICE_PATH" <<EOF
[Unit]
Description=Enable Bluetooth USB wake
After=bluetooth.service
Wants=bluetooth.service

[Service]
Type=oneshot
ExecStart=$INSTALL_PATH --enable
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now enable-bluetooth-wake.service

echo
echo "Bluetooth USB wake has been configured."
echo
echo "Current service status:"
systemctl --no-pager --full status enable-bluetooth-wake.service
echo
echo "Test suspend with:"
echo "  systemctl suspend"
