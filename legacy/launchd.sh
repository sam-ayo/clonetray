#!/bin/bash

PLIST_PATH="$HOME/Library/LaunchAgents/com.user.clonetray.plist"
PLIST_LABEL="com.user.clonetray" # Define label directly

# Function to create the plist file
create_plist() {
    echo "Plist file not found at $PLIST_PATH. Creating..."
    mkdir -p "$(dirname "$PLIST_PATH")"

    # Get the absolute path of the script's directory
    local SCRIPT_DIR
    SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
    local PYTHON_EXEC
    PYTHON_EXEC=$(which python3)
    local TRAY_SCRIPT="$SCRIPT_DIR/tray_clone.py" # Assuming tray_clone.py is in the same dir

    # Check if python3 exists
    if [ -z "$PYTHON_EXEC" ]; then
        echo "Error: python3 command not found. Please install Python 3."
        exit 1
    fi

    # Check if tray_clone.py exists
    if [ ! -f "$TRAY_SCRIPT" ]; then
        echo "Error: tray_clone.py not found in $SCRIPT_DIR."
        echo "Expected location: $TRAY_SCRIPT"
        exit 1
    fi

    cat << EOF > "$PLIST_PATH"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${PLIST_LABEL}</string>

    <key>ProgramArguments</key>
    <array>
        <string>${PYTHON_EXEC}</string>
        <string>${TRAY_SCRIPT}</string>
    </array>

    <key>RunAtLoad</key>
    <true/>

    <key>KeepAlive</key>
    <true/>

    <key>StandardOutPath</key>
    <string>/tmp/${PLIST_LABEL}.stdout.log</string>

    <key>StandardErrorPath</key>
    <string>/tmp/${PLIST_LABEL}.stderr.log</string>

    <key>WorkingDirectory</key>
    <string>${SCRIPT_DIR}</string>

    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin</string>
        <!-- Add python path if necessary, though absolute path is used -->
        <!-- <string>${PYTHON_EXEC%/*}:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin</string> -->
    </dict>
</dict>
</plist>
EOF

    if [ $? -eq 0 ]; then
        echo "Plist file created successfully at $PLIST_PATH."
    else
        echo "Error: Failed to create plist file at $PLIST_PATH."
        exit 1
    fi
}

# Check if plist exists, create if not
if [ ! -f "$PLIST_PATH" ]; then
    create_plist
fi

# Verify plist integrity after potential creation
LABEL_CHECK=$(/usr/libexec/PlistBuddy -c "Print :Label" "$PLIST_PATH" 2>/dev/null)
if [ -z "$LABEL_CHECK" ] || [ "$LABEL_CHECK" != "$PLIST_LABEL" ]; then
     echo "Error: Could not read label '$PLIST_LABEL' from $PLIST_PATH."
     echo "The plist file might be corrupted or inaccessible."
     # Consider adding troubleshooting steps or attempting recreation
     exit 1
fi

# Define LABEL based on the constant defined earlier
LABEL="$PLIST_LABEL"

start() {
    if launchctl list | grep -q "$LABEL"; then
        echo "Service $LABEL is already loaded."
    else
        echo "Loading service $LABEL..."
        launchctl load "$PLIST_PATH"
        if [ $? -eq 0 ]; then
            echo "Service $LABEL loaded successfully."
        else
            echo "Failed to load service $LABEL."
        fi
    fi
}

stop() {
    if launchctl list | grep -q "$LABEL"; then
        echo "Unloading service $LABEL..."
        launchctl unload "$PLIST_PATH"
        if [ $? -eq 0 ]; then
            echo "Service $LABEL unloaded successfully."
        else
            echo "Failed to unload service $LABEL."
            # Optionally force stop if unload fails
            # launchctl stop "$LABEL"
            # launchctl remove "$LABEL"
        fi
    else
        echo "Service $LABEL is not loaded."
    fi
}

status() {
    if launchctl list | grep -q "$LABEL"; then
        echo "Service $LABEL is loaded."
        # Add more detailed status if needed, e.g., PID
        # launchctl list "$LABEL"
    else
        echo "Service $LABEL is not loaded."
    fi
}

case "$1" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    restart)
        stop
        sleep 1 # Give time for the service to fully stop
        start
        ;;
    status)
        status
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status}"
        exit 1
        ;;
esac

exit 0
