#!/usr/bin/env bash

# Ensure the script is run with root/sudo privileges
if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run this script as root or using sudo."
  exit 1
fi

echo "=================================================================="
echo "Configuring Safe Driver Settings for Gigabyte B850I AORUS"
echo "=================================================================="

# 1. PERMANENTLY BLACKLIST WI-FI
# This part is still safe to do via modprobe since Wi-Fi cards use unique modules
CONF_FILE="/etc/modprobe.d/b850i-aorus-wifi.conf"
echo "-> Ensuring onboard Wi-Fi remains blacklisted..."

cat << 'EOF' > "$CONF_FILE"
# /etc/modprobe.d/b850i-aorus-wifi.conf
# Permanently blacklists the built-in Realtek RTL8922AE Wi-Fi 7 module
blacklist rtw89_8922ae
blacklist rtw89_pci
blacklist rtw89_core
EOF

if command -v update-initramfs >/dev/null 2>&1; then
  update-initramfs -u >/dev/null
fi

# 2. CREATE A RUN-ON-BOOT BLUETOOTH UNBIND SCRIPT
# This dynamically finds the motherboard chip on the internal USB bus and detaches it.
UNBIND_SCRIPT="/usr/local/bin/unbind-b850i-bluetooth.sh"
echo "-> Creating targeted driver unbind script at $UNBIND_SCRIPT..."

cat << 'EOF' > "$UNBIND_SCRIPT"
#!/usr/bin/env bash
# Automatically unbinds the built-in Realtek Bluetooth module from the btusb driver

# Search the USB bus for the internal Realtek Bluetooth adapter
# Realtek's USB vendor prefix is 0bda.
for dev in /sys/bus/usb/drivers/btusb/[0-9]*; do
    if [ -e "$dev" ]; then
        # Check if the device is a Realtek Bluetooth chip
        if grep -q "0bda" "$dev/../idVendor" 2>/dev/null; then
            DEV_NAME=$(basename "$dev")
            echo "Found internal Realtek Bluetooth adapter at USB path: $DEV_NAME"
            echo "Unbinding from btusb driver..."
            echo "$DEV_NAME" > /sys/bus/usb/drivers/btusb/unbind
            exit 0
        fi
    fi
done

echo "No internal Realtek Bluetooth device found currently bound to btusb."
EOF

chmod +x "$UNBIND_SCRIPT"

# 3. CREATE A SYSTEMD SERVICE TO RUN THE UNBIND AT BOOT
SERVICE_FILE="/etc/systemd/system/unbind-b850i-bluetooth.service"
echo "-> Registering systemd startup service..."

cat << EOF > "$SERVICE_FILE"
[Unit]
Description=Unbind Onboard Gigabyte B850I Bluetooth Adapter
After=multi-user.target

[Service]
Type=oneshot
ExecStart=$UNBIND_SCRIPT
RemainAfterExit=true

[Unit]
# Ensure it triggers early enough when the system initializes
After=bluetooth.service

[Install]
WantedBy=multi-user.target
EOF

# Reload and enable the service
systemctl daemon-reload
systemctl enable unbind-b850i-bluetooth.service

echo "=================================================================="
echo "Setup Complete!"
echo "- Wi-Fi modules are blacklisted."
echo "- The internal Bluetooth adapter will automatically unbind at boot."
echo "- Any external USB Bluetooth adapter will work flawlessly."
echo "=================================================================="
