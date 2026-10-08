#!/usr/bin/env bash

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script with sudo (e.g., sudo ./enable-wol.sh)"
  exit 1
fi

echo "Detecting active wired connection..."

# Find the active Ethernet connection name using nmcli
CONN_NAME=$(nmcli -t -f NAME,TYPE connection show --active | grep ethernet | head -n1 | cut -d: -f1)

# If no active connection, fallback to any wired connection profile
if [ -z "$CONN_NAME" ]; then
    CONN_NAME=$(nmcli -t -f NAME,TYPE connection show | grep ethernet | head -n1 | cut -d: -f1)
fi

if [ -z "$CONN_NAME" ]; then
    echo "ERROR: No Ethernet connection profile found in NetworkManager."
    exit 1
fi

echo "Found Ethernet connection profile: '$CONN_NAME'"
echo "Enabling Wake-on-LAN (Magic Packet)..."

# Modify connection to enable magic packet WoL
nmcli connection modify "$CONN_NAME" 802-3-ethernet.wake-on-lan magic

if [ $? -eq 0 ]; then
    echo "Successfully enabled WoL for '$CONN_NAME'!"
    echo "Applying changes..."
    nmcli connection up "$CONN_NAME"
    echo "Done! Make sure 'PME Event Wake Up' is enabled and 'ErP' is disabled in your BIOS."
else
    echo "ERROR: Failed to modify the connection settings."
    exit 1
fi
