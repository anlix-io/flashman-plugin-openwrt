#!/bin/sh

. /usr/share/functions/device_functions.sh
. /usr/share/functions/network_functions.sh
. /usr/share/functions/wireless_functions.sh

BRIDGE_IP_ADDR="$(get_lan_bridge_ipaddr)"
MAC="$(get_mac)"
SSID="$(get_wifi_local_config | jsonfilter -e '@["_ssid_24"]')"
SSID_5="$(get_wifi_local_config | jsonfilter -e '@["_ssid_50"]')"

minisapo "$BRIDGE_IP_ADDR" "$MAC" "$SSID" "$SSID_5"
