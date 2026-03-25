#!/usr/bin/env bash

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
#   INTRODUCTION
#
#   This script is intended to be run after the installation of Forticlient VPN before perorming any other setup steps.
#   It will export the automatically generated configuration file (xml) in the /tmp directory.
#   The script will then use that plain configuration file and apply the specified modifications to it (VPN server address, port, etc)
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #


set -euo pipefail

# LOGGING helper function for nice output
LOG_FILE="/var/log/setupScripts/forticlient-vpn-configuration.log"
log() {
  local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
  echo "$msg"
  echo "$msg" >> "$LOG_FILE"
}

FCC="/Library/Application Support/Fortinet/FortiClient/bin/FCConfig"
CONFIG_DIR="/tmp/forticlient_vpn_setup"
CONFIG_DESTINATION="$CONFIG_DIR/vpn_config.xml"

#create directory if missing, otherwise this action will do nothing
mkdir -p "$CONFIG_DIR"

if [[ ! -d "$CONFIG_DIR" ]]; then
    log "Error: Failed to create or cannot find directory: $CONFIG_DIR"
    exit 1
fi

# Check if FortiClient configuration tool exists
if [[ ! -x "$FCC" ]]; then
    log "Error: FortiClient configuration tool not found or not executable."
    log "Expected location: $FCC"
    exit 1
fi

# Attempt export
log "Exporting VPN configuration..."
log "" 

if "$FCC" -f "$CONFIG_DESTINATION" -m all -o export; then
    log "Success: VPN configuration exported to $CONFIG_DESTINATION"
else
    log "Error: Failed to export VPN configuration."
    exit 1
fi


# -----------------------------
# CREATING A DEFAULT SSL VPN CONNECTION BLOCK WITH THE PROVIDED SETTINGS 
# -----------------------------

#VPN Settings
VPN_NAME="MYVPN_Name"
VPN_DESCRIPTION="Description"
VPN_SERVER_HOST="IP_OR_NAME"
VPN_SERVER_PORT="PORT"
VPN_USERNAME=$(whoami)   # optional - get current username


#Options for SSL VPN connection:  (0 or 1)
SSL_VPN_OPTION_WARN_INVALID_SERVER_CERTIFICATE=0


# Build the connection block we would insert if there are no connections yet.
# NOTE: certificate is intentionally EMPTY / omitted to avoid copying machine-specific Enc fields
CONNECTION_BLOCK=$(cat <<EOF
                <connection>
                    <vpn_type></vpn_type>
                    <name>${VPN_NAME}</name>
                    <description>${VPN_DESCRIPTION}</description>
                    <server>${VPN_SERVER_HOST}:${VPN_SERVER_PORT}</server>
                    <username>${VPN_USERNAME}</username>
                    <password></password>
                    <warn_invalid_server_certificate>1</warn_invalid_server_certificate>
                    <dual_stack>0</dual_stack>
                    <sso_enabled>0</sso_enabled>
                    <keep_fqdn_resolution_consistency>0</keep_fqdn_resolution_consistency>
                    <use_external_browser>0</use_external_browser>
                    <fido_auth>0</fido_auth>
                    <redundant_sort_method>0</redundant_sort_method>
                    <ssl_vpn_method>0</ssl_vpn_method>
                    <prompt_certificate>0</prompt_certificate>
                    <prompt_username>0</prompt_username>
                    <on_connect>
                        <script>
                            <os>mac</os>
                            <script></script>
                        </script>
                    </on_connect>
                    <on_disconnect>
                        <script>
                            <os>mac</os>
                            <script></script>
                        </script>
                    </on_disconnect>
                    <tags>
                        <allowed></allowed>
                        <prohibited></prohibited>
                    </tags>
                    <host_check_fail_warning></host_check_fail_warning>
                    <keep_running>0</keep_running>
                    <fgt>0</fgt>
                    <ui>
                        <show_remember_password>1</show_remember_password>
                        <show_alwaysup>0</show_alwaysup>
                        <show_autoconnect>0</show_autoconnect>
                        <save_username>1</save_username>
                        <save_password>1</save_password>
                    </ui>
                    <disclaimer_msg></disclaimer_msg>
                    <traffic_control>
                        <enabled>0</enabled>
                        <mode>2</mode>
                        <apps></apps>
                        <fqdns></fqdns>
                    </traffic_control>
                </connection>
EOF
)
MODIFIED_XML="$CONFIG_DIR/vpn_config.modified.xml"

log "-----BLOCK START-----"
log "$CONNECTION_BLOCK"
log "-----BLOCK END-----"

# ---------------------------------------------------------------------------------------
# MODIFY THE XML WITH PERL (INSERT NEW CONNECTION OR UPDATE EXISTING ONE)
# ---------------------------------------------------------------------------------------

# Export environment variables for Perl
export EXPORTED_XML="$CONFIG_DESTINATION"
export MODIFIED_XML
export VPN_NAME VPN_DESCRIPTION VPN_SERVER_HOST VPN_SERVER_PORT VPN_USERNAME
export CONNECTION_BLOCK
export SSL_VPN_OPTION_WARN_INVALID_SERVER_CERTIFICATE


# Check if Perl is available
if ! command -v perl &> /dev/null; then
    log "Error: Perl is not installed on machine or not available in PATH."
    exit 1
fi


# Perl normally reads input line by line. With -0777, it reads the entire file as one big string into $_
# flags explained: 
# -p : loop over input, and print $_ automatically after processing.
# -e : run the code provided as a command-line string (instead of a .pl file)
# Perl receives "$EXPORTED_XML" as an input file argument


/usr/bin/perl -0777 -pe '
  use strict;
  use warnings;

  my $block = $ENV{CONNECTION_BLOCK} // die "CONNECTION_BLOCK not set\n";
  my $warn_cert = $ENV{SSL_VPN_OPTION_WARN_INVALID_SERVER_CERTIFICATE} // 1;

  # update options (warning invalid server certificate)
  s{
      (<sslvpn>.*?<options>.*?<warn_invalid_server_certificate>)
      \d+
      (</warn_invalid_server_certificate>)
  }{$1$warn_cert$2}xs
  or die "Could not update <warn_invalid_server_certificate>\n";


  # Insert block right before </connections> inside <sslvpn>...</sslvpn>
  # This targets the connections section that belongs to sslvpn.
  if (s{(<sslvpn>.*?<connections>)(.*?)(</connections>)}{$1$2\n$block\n$3}xs) {
    # ok
  } else {
    die "Could not locate <sslvpn><connections>...</connections>\n";
  }
' "$EXPORTED_XML" > "$MODIFIED_XML"

log ""
log "Modified XML written to: $MODIFIED_XML"
log ""


# -----------------------------
# SANITY CHECKS FOR MODIFIED XML
# -----------------------------
if [[ ! -s "$MODIFIED_XML" ]]; then
  log "Error: Modified XML is empty: $MODIFIED_XML"
  exit 1
fi

if ! grep -q "<sslvpn>" "$MODIFIED_XML"; then
  log "Error: Modified XML missing <sslvpn> block."
  exit 1
fi

if ! grep -q "<connections>" "$MODIFIED_XML"; then
  log "Error: Modified XML missing <connections> block."
  exit 1
fi

if ! grep -q "<name>${VPN_NAME}</name>" "$MODIFIED_XML"; then
  log "Error: Modified XML does not contain expected connection name: $VPN_NAME"
  exit 1
fi


# -----------------------------
# import modified config file back to forticlient
# -----------------------------

# Check if configuration file exists
if [[ ! -f "$MODIFIED_XML" ]]; then
    log "Error: Configuration file not found at: $MODIFIED_XML"
    exit 1
fi

# Attempt import
log ""
log ""
log "Importing VPN configuration from file $MODIFIED_XML..."

if sudo "$FCC" -m all -f "$MODIFIED_XML" -o import; then
    log "Success: VPN configuration imported from $MODIFIED_XML"
else
    log "Error: Failed to import VPN configuration."
    exit 1
fi