#!/usr/bin/env bash

set -euo pipefail

FCC="/Library/Application Support/Fortinet/FortiClient/bin/FCConfig"
USER_NAME="$(whoami)"

#NOTE: Choose a path thats not dependent on the user since the import command is run as root
CONFIG_DESTINATION="/Users/${USER_NAME}/Downloads/vpn_config.xml"

# Check if FortiClient configuration tool exists
if [[ ! -x "$FCC" ]]; then
    echo "Error: FortiClient configuration tool not found or not executable."
    echo "Expected location: $FCC"
    exit 1
fi

# Check if configuration file exists
if [[ ! -f "$CONFIG_DESTINATION" ]]; then
    echo "Error: Configuration file not found at: $CONFIG_DESTINATION"
    exit 1
fi

# Attempt import
echo "Importing VPN configuration from file $CONFIG_DESTINATION..."

if sudo "$FCC" -m all -f "$CONFIG_DESTINATION" -o import; then
    echo "Success: VPN configuration imported from $CONFIG_DESTINATION"
else
    echo "Error: Failed to import VPN configuration."
    exit 1
fi
