#!/bin/bash

TARGET_DIR="$HOME/.strata"
SYSTEMD_DIR="$HOME/.config/systemd/user"
STEAM_CONFIG_DIR=$(find "$HOME/.local/share/Steam/userdata" -maxdepth 2 -name "shortcuts.vdf" 2>/dev/null | head -n 1)

echo "=== 1. CREATING DIRECTORIES ==="
mkdir -p "$TARGET_DIR"
mkdir -p "$SYSTEMD_DIR"

echo "=== 2. CREATING UPDATER SCRIPT ==="
cat << 'EOF' > "$HOME/update_strata.sh"
#!/bin/bash
TARGET_DIR="$HOME/.strata"
TEMP_DIR="$HOME/.strata_tmp"

rm -rf "$TEMP_DIR"
git clone --depth 1 https://github.com "$TEMP_DIR"

if [ $? -eq 0 ] && [ -d "$TEMP_DIR/.git" ]; then
    [ -f "$TARGET_DIR/config.json" ] && mv "$TARGET_DIR/config.json" "$TEMP_DIR/config.json"
    rm -rf "$TARGET_DIR"/*
    cp -r "$TEMP_DIR"/* "$TARGET_DIR/"
    rm -rf "$TEMP_DIR"
    chmod +x "$TARGET_DIR/setup.sh"
    echo "[$(date)] Strata updated successfully."
else
    echo "[$(date)] ERROR: Download failed. Keeping old files."
    rm -rf "$TEMP_DIR"
    exit 1
fi
EOF
chmod +x "$HOME/update_strata.sh"

echo "=== 3. RUNNING INITIAL DOWNLOAD ==="
"$HOME/update_strata.sh"

echo "=== 4. CREATING LAUNCHER SCRIPT ==="
cat << 'EOF' > "$HOME/launch_strata.sh"
#!/bin/bash
TARGET_DIR="$HOME/.strata"
CUSTOM_PORT=9000

STRATA_PID=$(pgrep -f "setup.sh.*--port $CUSTOM_PORT")

if [ -z "$STRATA_PID" ]; then
    cd "$TARGET_DIR" || exit 1
    ./setup.sh --port $CUSTOM_PORT --host 0.0.0.0 &
    while true; do sleep 2; done
else
    kill "$STRATA_PID"
    sleep 1
fi
EOF
chmod +x "$HOME/launch_strata.sh"

echo "=== 5. SETTING UP DAILY BACKGROUND TIMER ==="
cat << EOF > "$SYSTEMD_DIR/strata-update.service"
[Unit]
Description=Daily Automatic Strata Core Update
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=$HOME/update_strata.sh
StandardOutput=append:$HOME/.strata_update.log
StandardError=append:$HOME/.strata_update.log

[Install]
WantedBy=default.target
EOF

cat << EOF > "$SYSTEMD_DIR/strata-update.timer"
[Unit]
Description=Trigger Strata Update Every 24 Hours

[Timer]
OnUnitActiveSec=24h
OnBootSec=15min
RandomizedDelaySec=5min
Persistent=true

[Install]
WantedBy=timers.target
EOF

systemctl --user daemon-reload
systemctl --user enable strata-update.timer
systemctl --user start strata-update.timer

echo "=== 6. ADDING TO STEAM SHORTCUTS ==="
if [ -n "$STEAM_CONFIG_DIR" ]; then
    # Inject a clean native shortcut configuration string straight into Steam's VDF database
    # This keeps the user layout fully pristine while dropping the launcher into place
    printf "\x00shortcuts\x00\x010\x00\x02AppName\x00Strata AI Engine\x00\x02Exe\x00\"$HOME/launch_strata.sh\"\x00\x02StartDir\x00\"$HOME/\"\x00\x08\x08" >> "$STEAM_CONFIG_DIR"
    echo "Added 'Strata AI Engine' to your Non-Steam library database!"
    echo "⚠️ NOTE: Please completely close and restart Steam to see the new shortcut link appear."
else
    echo "Could not auto-detect Steam folder path. Please add '$HOME/launch_strata.sh' manually via 'Add Non-Steam Game'."
fi

echo "=== INSTALLATION COMPLETE ==="
