#!/bin/sh

. /usr/share/flashman_init.conf
. /usr/share/functions/device_functions.sh

HOSTNAME=$(get_mac | sed -e "s/:/-/g")

uci set system.@system[-1].timezone="BRT3BRST,M10.3.0/0,M2.3.0/0"
uci set system.@system[-1].hostname="$HOSTNAME"
uci set system.@system[-1].cronloglevel="9"
uci set system.ntp.enabled="1"
uci set system.ntp.enable_server="0"
uci -q delete system.ntp.server
uci add_list system.ntp.server="$NTP_SVADDR"

uci commit system

exit 0
