#!/usr/bin/env bash

set -euo pipefail

FCC="/Library/Application Support/Fortinet/FortiClient/bin/FCConfig"
USER_NAME="$(whoami)"
CONFIG_DESTINATION="/Users/${USER_NAME}/Downloads/vpn_config.xml"

# Check if FortiClient configuration tool exists
if [[ ! -x "$FCC" ]]; then
    echo "Error: FortiClient configuration tool not found or not executable."
    echo "Expected location: $FCC"
    exit 1
fi

# Check if directory exists
DOWNLOADS_DIR="/Users/${USER_NAME}/Downloads"
if [[ ! -d "$DOWNLOADS_DIR" ]]; then
    echo "Error: Destination directory does not exist: $DOWNLOADS_DIR"
    exit 1
fi

# Attempt export
echo "Exporting VPN configuration..."

if "$FCC" -f "$CONFIG_DESTINATION" -m all -o export; then
    echo "Success: VPN configuration exported to $CONFIG_DESTINATION"
else
    echo "Error: Failed to export VPN configuration."
    exit 1
fi