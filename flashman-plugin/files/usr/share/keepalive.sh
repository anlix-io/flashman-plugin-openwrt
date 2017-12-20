#!/bin/sh

. /usr/share/flashman_init.conf
. /usr/share/functions.sh

SERVER_ADDR="$FLM_SVADDR"
OPENWRT_VER=$(cat /etc/openwrt_version)
HARDWARE_MODEL=$(cat /proc/cpuinfo | sed -n 2p | awk '{ print $4 }' | sed 's/\//-/g')
CLIENT_MAC=$(get_mac)
WAN_IP_ADDR=$(get_wan_ip)
PPPOE_USER=""
PPPOE_PASSWD=""
WIFI_SSID=""
WIFI_PASSWD=""
WIFI_CHANNEL=""

while true
do
	sleep 300

	_number=$(head /dev/urandom | tr -dc "012345" | head -c1)

	if [ "$_number" -eq 3 ] || [ "$1" == "now" ]
	then
		# Get PPPoE data if available
		if [ "$(uci get network.wan.proto)" == "pppoe" ]
		then
			PPPOE_USER=$(uci get network.wan.username)
			PPPOE_PASSWD=$(uci get network.wan.password)
		fi

		# Get WiFi data if available
		if [ "$(uci get wireless.@wifi-device[0].disabled)" == "0" ]
		then
			WIFI_SSID=$(uci get wireless.@wifi-iface[0].ssid)
			WIFI_PASSWD=$(uci get wireless.@wifi-iface[0].key)
			WIFI_CHANNEL=$(uci get wireless.radio0.channel)
		fi

		curl -s -A "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1)" \
		    -k --connect-timeout 5 --retry 0 \
		    --data "id=$CLIENT_MAC&version=$OPENWRT_VER&model=$HARDWARE_MODEL&release_id=$FLM_RELID&pppoe_user=$PPPOE_USER&pppoe_password=$PPPOE_PASSWD&wan_ip=$WAN_IP_ADDR&wifi_ssid=$WIFI_SSID&wifi_password=$WIFI_PASSWD&wifi_channel=$WIFI_CHANNEL" \
		    "https://$SERVER_ADDR/deviceinfo/syn/")
	fi
done
