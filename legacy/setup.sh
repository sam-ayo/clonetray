#!/bin/bash

# Get the absolute path to the directory containing this script
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

TEMPLATE_FILE="${SCRIPT_DIR}/com.user.clonetray.plist.template"
TARGET_DIR="$HOME/Library/LaunchAgents"
TARGET_FILE="${TARGET_DIR}/com.user.clonetray.plist"

# Ensure the target directory exists
mkdir -p "${TARGET_DIR}"

# Check if template file exists
if [ ! -f "${TEMPLATE_FILE}" ]; then
    echo "Error: Template file not found at ${TEMPLATE_FILE}"
    exit 1
fi

# Replace the placeholder with the actual working directory
# Using '|' as the sed delimiter to avoid issues with paths containing '/'
sed "s|__WORKING_DIRECTORY__|${SCRIPT_DIR}|" "${TEMPLATE_FILE}" > "${TARGET_FILE}"

if [ $? -eq 0 ]; then
    echo "Successfully created plist file at ${TARGET_FILE}"
    echo "Working directory set to: ${SCRIPT_DIR}"
    echo ""
    echo "To load the service, run:"
    echo "launchctl load ${TARGET_FILE}"
    echo "(Or use ./launchd.sh start)"
    echo ""
    echo "To make the script executable, run: chmod +x setup.sh"
else
    echo "Error: Failed to create plist file at ${TARGET_FILE}"
    exit 1
fi

exit 0 