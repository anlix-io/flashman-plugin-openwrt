#!/bin/sh

. /usr/share/flashman_init.conf
. /usr/share/functions.sh

HOSTNAME=$(echo $CLIENT_MAC | sed -e "s/:/-/g")

uci set system.@system[-1].timezone="BRT3BRST,M10.3.0/0,M2.3.0/0"
uci set system.@system[-1].hostname="$HOSTNAME"
uci set system.@system[-1].cronloglevel="9"
uci set system.ntp.enabled="1"
uci set system.ntp.enable_server="0"
uci -q delete system.ntp.server
uci add_list system.ntp.server="$NTP_SVADDR"
# LEDs
uci set system.led_wifi_led.dev="ra0"
uci set system.led_wlan2g.dev="ra0"
uci set system.led_wlan5g=led
uci set system.led_wlan5g.name='wlan5g'
uci set system.led_wlan5g.sysfs='archer-c20-v4:green:wlan5g'
uci set system.led_wlan5g.trigger='netdev'
uci set system.led_wlan5g.dev='rai0'
uci set system.led_wlan5g.mode='link tx rx'

uci commit system

exit 0
