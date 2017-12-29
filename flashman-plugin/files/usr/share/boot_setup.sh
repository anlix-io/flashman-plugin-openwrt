#!/bin/sh

. /usr/share/flashman_init.conf
. /lib/functions.sh
. /usr/share/functions.sh

HARDWARE_MODEL=$(cat /tmp/sysinfo/model | awk '{ print toupper($2) }')
CLIENT_MAC=$(get_mac)
HOSTNAME=$(echo $CLIENT_MAC | sed -e "s/:/-/g")
MAC_LAST_CHARS=$(echo $CLIENT_MAC | awk -F: '{ print $5$6 }')
DISTRIBID=$(head -1 /etc/openwrt_release | awk -F = '{ print $2 }')

# Wireless password cannot be empty or have less than 8 chars
if [ "$FLM_PASSWD" == "" ] || [ $(echo "$FLM_PASSWD" | wc -m) -lt 9 ]
then
	FLM_PASSWD=$(echo $CLIENT_MAC | sed -e "s/://g")
fi

log() {
	logger -t "FlashMan Plugin Boot " "$@"
}

firstboot() {
	uci set system.@system[-1].timezone="BRT3BRST,M10.3.0/0,M2.3.0/0"
	uci set system.@system[-1].hostname="$HOSTNAME"
	uci set system.@system[-1].cronloglevel="9"
	uci commit system

	uci set system.ntp.enabled="0"
	uci set system.ntp.enable_server="0"
	uci commit system
	/etc/init.d/system restart

	# Set firewall rules
	uci set firewall.@defaults[-1].input="ACCEPT"
	uci set firewall.@defaults[-1].output="ACCEPT"
	uci set firewall.@defaults[-1].forward="REJECT"
	uci commit firewall

	# Lan
	uci set firewall.@zone[0].input="ACCEPT"
	uci set firewall.@zone[0].output="ACCEPT"
	uci set firewall.@zone[0].forward="REJECT"
	uci commit firewall

	# Wan
	uci set firewall.@zone[1].input="ACCEPT"
	uci set firewall.@zone[1].output="ACCEPT"
	uci set firewall.@zone[1].forward="REJECT"
	uci set firewall.@zone[1].network="wan"
	uci commit firewall

	# SSH access
	uci add firewall rule
	uci set firewall.@rule[-1].enabled="1"
	uci set firewall.@rule[-1].target="ACCEPT"
	uci set firewall.@rule[-1].proto="tcp"
	uci set firewall.@rule[-1].dest_port="36022"
	uci set firewall.@rule[-1].name="custom-ssh"
	uci set firewall.@rule[-1].src="*"
	uci commit firewall

	uci set dropbear.@dropbear[0]=dropbear
	uci set dropbear.@dropbear[0].PasswordAuth=off
	uci set dropbear.@dropbear[0].RootPasswordAuth=off
	uci set dropbear.@dropbear[0].Port=36022
	uci commit dropbear
	/etc/init.d/dropbear restart

	# Configure WiFi default SSID and password
	ssid_value=$(uci get wireless.@wifi-iface[0].ssid)
	encryption_value=$(uci get wireless.@wifi-iface[0].encryption)
	if [ "$encryption_value" = "none" ] && { [ "$ssid_value" = "OpenWrt" ] || [ "$ssid_value" = "LEDE" ]; }
	then
		uci set wireless.@wifi-device[0].disabled="0"
		uci set wireless.@wifi-device[0].type="mac80211"
		# Auto mode doesn't work on current WR840N release. MediaTek 7728 instability.
		if [ "$HARDWARE_MODEL" = "TL-WR840N" ]
		then
			uci set wireless.@wifi-device[0].channel="11"
		else
			uci set wireless.@wifi-device[0].channel="$FLM_24_CHANNEL"
		fi
		uci set wireless.@wifi-device[0].hwmode="11n"
		uci set wireless.@wifi-device[0].country="BR"
		uci set wireless.@wifi-device[0].txpower="17"
		uci commit wireless
		uci set wireless.@wifi-iface[0].ssid="$FLM_SSID$MAC_LAST_CHARS"
		uci set wireless.@wifi-iface[0].encryption="psk2"
		uci set wireless.@wifi-iface[0].key="$FLM_PASSWD"
		uci commit wireless
		uci set wireless.@wifi-device[1].disabled="0"
		uci set wireless.@wifi-device[1].type="mac80211"
		uci set wireless.@wifi-device[1].channel="36"
		uci commit wireless
		uci set wireless.@wifi-iface[1].ssid="$FLM_SSID$MAC_LAST_CHARS"
		uci set wireless.@wifi-iface[1].encryption="psk2"
		uci set wireless.@wifi-iface[1].key="$FLM_PASSWD"
		uci commit wireless
	fi
	/sbin/wifi up

	# Configure LAN
	uci set network.lan.ipaddr="10.0.10.1"
	uci set network.lan.netmask="255.255.255.0"
	uci commit network
	/sbin/ifup lan

	# Configure WAN
	wan_proto_value=$(uci get network.wan.proto)
	uci set network.wan.proto="$FLM_WAN_PROTO"
	uci set network.wan.mtu="$FLM_WAN_MTU"
	if [ "$FLM_WAN_PROTO" = "pppoe" ] && [ "$wan_proto_value" != "pppoe" ]
	then
		uci set network.wan.username="$FLM_WAN_PPPOE_USER"
		uci set network.wan.password="$FLM_WAN_PPPOE_PASSWD"
		uci set network.wan.service="$FLM_WAN_PPPOE_SERVICE"
	fi
	uci commit network
	/etc/init.d/network restart

	# Set root password
	PASSWORD_ENTRY=""
	(
		echo "$CLIENT_MAC" | awk -F ":" '{ print $1$2$3$4$5$6 }'
		sleep 1
		echo "$CLIENT_MAC" | awk -F ":" '{ print $1$2$3$4$5$6 }'
	)|passwd root

	# Sync date and time with GMT-3
	ntpd -n -q -p $NTP_SVADDR

	# Configure Zabbix
	sed -i "s%ZABBIX-SERVER-ADDR%$ZBX_SVADDR%" /etc/zabbix_agentd.conf
	_count_logtype=$(grep -c "LogType" /etc/zabbix_agentd.conf)
	if [ "$DISTRIBID" == "'LEDE'" ] && [ "$_count_logtype" -lt 1 ]
	then
		echo "LogType=system" >> /etc/zabbix_agentd.conf
	fi
	# Enable Zabbix
	/etc/init.d/zabbix_agentd enable
	/etc/init.d/zabbix_agentd start

	log "First boot completed"
}

log "Starting..."

[ -f "/etc/firstboot" ] || {
	firstboot
}

log "Done!"

echo "0" > /etc/firstboot
