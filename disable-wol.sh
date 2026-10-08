#!/usr/bin/env bash

# Check if script is running as root
if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run this script with sudo."
  exit 1
fi

# Find the active wired connection profile name
WIRED_CONN=$(nmcli -t -f NAME,TYPE connection show --active | grep "802-3-ethernet" | head -n 1 | cut -d':' -f1)

# If no active connection, fallback to checking all wired profiles
if [ -z "$WIRED_CONN" ]; then
  WIRED_CONN=$(nmcli -t -f NAME,TYPE connection show | grep "802-3-ethernet" | head -n 1 | cut -d':' -f1)
fi

if [ -z "$WIRED_CONN" ]; then
  echo "Error: No Ethernet connection found to modify."
  exit 1
fi

echo "Found Ethernet connection: '$WIRED_CONN'"
echo "Disabling Wake-on-LAN..."

# Revert the WOL setting back to default/disabled
nmcli connection modify "$WIRED_CONN" 802-3-ethernet.wake-on-lan default

if [ $? -eq 0 ]; then
  echo "Successfully reset Wake-on-LAN settings."
  echo "Restarting network connection..."
  nmcli connection up "$WIRED_CONN"
  echo "Done! The changes have been reverted."
else
  echo "Error: Failed to reset Wake-on-LAN settings."
  exit 1
fi
