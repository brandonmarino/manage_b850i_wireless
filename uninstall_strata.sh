#!/bin/bash

TARGET_DIR="$HOME/.strata"
SYSTEMD_DIR="$HOME/.config/systemd/user"

echo "=== 1. STOPPING BACKGROUND TIMERS ==="
systemctl --user stop strata-update.timer 2>/dev/null
systemctl --user disable strata-update.timer 2>/dev/null

echo "=== 2. REMOVING SYSTEMD TIMERS ==="
rm -f "$SYSTEMD_DIR/strata-update.service"
rm -f "$SYSTEMD_DIR/strata-update.timer"
systemctl --user daemon-reload

echo "=== 3. TERMINATING ACTIVE STRATA RUNNERS ==="
# Hard-kill any leftover backend server iterations running on the custom port
pkill -f "setup.sh.*--port 9000"
pkill -f "launch_strata.sh"

echo "=== 4. PURGING FILES ==="
rm -rf "$TARGET_DIR"
rm -f "$HOME/update_strata.sh"
rm -f "$HOME/launch_strata.sh"
rm -f "$HOME/.strata_update.log"

echo "=== UNINSTALL COMPLETE ==="
echo "Note: The shortcut has been neutralised. To clean your Steam interface, right-click 'Strata AI Engine' in your library, go to Manage -> 'Remove non-Steam game'."
