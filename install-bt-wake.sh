#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="/var/lib/bt-wake"
INSTALL_PATH="$INSTALL_DIR/enable-bt-wake"
SERVICE_PATH="/etc/systemd/system/enable-bt-wake.service"

enable_wake() {
    local found=0

    for _ in {1..20}; do
        for hci in /sys/class/bluetooth/hci*/device; do
            [[ -e "$hci" ]] || continue

            device="$(realpath -e "$hci" 2>/dev/null || true)"
            [[ -n "$device" ]] || continue

            parent="$device"

            while [[ "$parent" != "/" && "$parent" != "/sys" ]]; do
                if [[ -f "$parent/idVendor" &&
                      -f "$parent/power/wakeup" &&
                      -w "$parent/power/wakeup" ]]; then

                    vendor="$(cat "$parent/idVendor" 2>/dev/null || true)"

                    if printf '%s\n' enabled > "$parent/power/wakeup"; then
                        echo "Enabled Bluetooth wake"
                        echo "  Bluetooth device: $hci"
                        echo "  USB path:         $parent"
                        echo "  USB vendor:       $vendor"
                        echo "  Wake status:       $(cat "$parent/power/wakeup")"
                        found=1
                    fi

                    break
                fi

                parent="$(dirname "$parent")"
            done
        done

        [[ "$found" -eq 1 ]] && return 0
        sleep 1
    done

    echo "No Bluetooth USB adapter with writable wake support was found." >&2
    return 1
}

install_service() {
    if [[ "$EUID" -ne 0 ]]; then
        echo "Run this script with sudo:"
        echo "  sudo bash $0"
        exit 1
    fi

    mkdir -p "$INSTALL_DIR"

    # Install this same script as the persistent runtime helper.
    install -o root -g root -m 0755 "$SOURCE_PATH" "$INSTALL_PATH"

    cat > "$SERVICE_PATH" <<EOF
[Unit]
Description=Enable Bluetooth USB wake
Wants=bluetooth.service
After=bluetooth.service

[Service]
Type=oneshot
ExecStart=$INSTALL_PATH --enable
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable --now enable-bt-wake.service

    echo
    echo "Bluetooth wake service installed and started."
    echo
    systemctl --no-pager --full status enable-bt-wake.service
}

SOURCE_PATH="$(readlink -f "$0")"

case "${1:-install}" in
    --enable)
        if [[ "$EUID" -ne 0 ]]; then
            echo "The wake helper must run as root." >&2
            exit 1
        fi
        enable_wake
        ;;
    install)
        install_service
        ;;
    *)
        echo "Usage:"
        echo "  sudo bash $0"
        exit 2
        ;;
esac
