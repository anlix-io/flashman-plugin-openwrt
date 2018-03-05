#!/bin/sh

. /usr/share/flashman_init.conf
. /usr/share/libubox/jshn.sh
. /usr/share/flash_image.sh
. /usr/share/functions.sh
. /usr/share/boot_setup.sh

SERVER_ADDR="$FLM_SVADDR"
OPENWRT_VER=$(cat /etc/openwrt_version)
HARDWARE_MODEL=$(get_hardware_model)
SYSTEM_MODEL=$(get_system_model)
HARDWARE_VER=$(cat /tmp/sysinfo/model | awk '{ print toupper($3) }')
NUMBER=$(head /dev/urandom | tr -dc "012345" | head -c1)
CLIENT_MAC=$(get_mac)
WAN_IP_ADDR=$(get_wan_ip)
PPPOE_USER=""
PPPOE_PASSWD=""
WIFI_SSID=""
WIFI_PASSWD=""
WIFI_CHANNEL=""

if [ "$NUMBER" -eq 3 ] || [ "$1" == "now" ]
then
  if is_authenticated
  then
    # Sync date and time with GMT-3
    ntpd -n -q -p $NTP_SVADDR

    # Get PPPoE data if available
    if [ "$(uci get network.wan.proto)" == "pppoe" ]
    then
      PPPOE_USER=$(uci get network.wan.username)
      PPPOE_PASSWD=$(uci get network.wan.password)
    fi

    # Get WiFi data if available
    # MT7628 wifi is always disabled in uci 
    if [ "$(uci get wireless.@wifi-device[0].disabled)" == "0" ] || [ "$SYSTEM_MODEL" == "MT7628AN" ]
    then
      WIFI_SSID=$(uci get wireless.@wifi-iface[0].ssid)
      WIFI_PASSWD=$(uci get wireless.@wifi-iface[0].key)
      WIFI_CHANNEL=$(uci get wireless.radio0.channel)
    fi

    _res=$(curl -s -A "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1)" \
           -k --connect-timeout 5 --retry 0 \
           --data "id=$CLIENT_MAC&version=$OPENWRT_VER&model=$HARDWARE_MODEL&model_ver=$HARDWARE_VER&release_id=$FLM_RELID&pppoe_user=$PPPOE_USER&pppoe_password=$PPPOE_PASSWD&wan_ip=$WAN_IP_ADDR&wifi_ssid=$WIFI_SSID&wifi_password=$WIFI_PASSWD&wifi_channel=$WIFI_CHANNEL" \
           "https://$SERVER_ADDR/deviceinfo/syn/")

    json_load "$_res"
    json_get_var _do_update do_update
    json_get_var _release_id release_id
    json_get_var _pppoe_user pppoe_user
    json_get_var _pppoe_password pppoe_password
    json_get_var _wifi_ssid wifi_ssid
    json_get_var _wifi_password wifi_password
    json_get_var _wifi_channel wifi_channel
    json_close_object

    # PPPoE update
    if [ "$(uci get network.wan.proto)" == "pppoe" ]
    then
      if [ "$_pppoe_user" != "" ] && [ "$_pppoe_password" != "" ]
      then
        if [ "$_pppoe_user" != "$PPPOE_USER" ] || \
           [ "$_pppoe_password" != "$PPPOE_PASSWD" ]
        then
          uci set network.wan.username="$_pppoe_user"
          uci set network.wan.password="$_pppoe_password"
          uci commit network

          /etc/init.d/network restart
        fi
      fi
    fi

    # WiFi update
    if [ "$(uci get wireless.@wifi-device[0].disabled)" == "0" ] || [ "$SYSTEM_MODEL" == "MT7628AN" ]
    then
      if [ "$_wifi_ssid" != "" ] && [ "$_wifi_password" != "" ] && \
         [ "$_wifi_channel" != "" ]
      then
        if [ "$_wifi_ssid" != "$WIFI_SSID" ] || \
           [ "$_wifi_password" != "$WIFI_PASSWD" ] || \
           [ "$_wifi_channel" != "$WIFI_CHANNEL" ]
        then
          uci set wireless.@wifi-iface[0].ssid="$_wifi_ssid"
          uci set wireless.@wifi-iface[0].key="$_wifi_password"
          uci set wireless.radio0.channel="$_wifi_channel"
          uci commit wireless

	  if [ "$SYSTEM_MODEL" == "MT7628AN" ]
	  then
            /usr/bin/uci2dat -d radio0 -f /etc/wireless/mt7628/mt7628.dat	
	    /sbin/mtkwifi reload
	  else
	    /etc/init.d/network restart
          fi
        fi
      fi
    fi

    if [ "$_do_update" == "1" ]
    then
      # Execute firmware update
      run_reflash $SERVER_ADDR $_release_id
    fi
  fi
fi
