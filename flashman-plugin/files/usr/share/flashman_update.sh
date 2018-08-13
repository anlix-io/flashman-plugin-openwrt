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
CLIENT_MAC=$(get_mac)
WAN_IP_ADDR=$(get_wan_ip)
WAN_CONNECTION_TYPE=$(uci get network.wan.proto | awk '{ print tolower($1) }')
PPPOE_USER=""
PPPOE_PASSWD=""
WIFI_SSID=""
WIFI_PASSWD=""
WIFI_CHANNEL=""
APP_PASSWORD=$(cat /root/router_passwd)

log "FLASHMAN UPDATER" "Start ..." 

if is_authenticated
then
  log "FLASHMAN UPDATER" "Authenticated ..."

  # Get PPPoE data if available
  if [ "$WAN_CONNECTION_TYPE" == "pppoe" ]
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

  # Report if a hard reset has occured
  if [ -e /root/hard_reset ]
  then
    log "FLASHMAN UPDATER" "Sending HARD RESET Information to server"
    HARDRESET="1"
    if [ -e /sysupgrade.tgz ]
    then
      rm /sysupgrade.tgz
    fi
  else
    HARDRESET="0"
  fi

  # Report a firmware upgrade
  if [ -e /root/upgrade_info ]
  then
    log "FLASHMAN UPDATER" "Sending UPGRADE FIRMWARE Information to server"
    UPGRADEFIRMWARE="1"
  else
    UPGRADEFIRMWARE="0"
  fi

  #Get NTP status
  NTP_INFO=$(ntp_anlix)

  _data="id=$CLIENT_MAC&flm_updater=1&version=$ANLIX_PKG_VERSION&model=$HARDWARE_MODEL&model_ver=$HARDWARE_VER&release_id=$FLM_RELID&pppoe_user=$PPPOE_USER&pppoe_password=$PPPOE_PASSWD&wan_ip=$WAN_IP_ADDR&wifi_ssid=$WIFI_SSID&wifi_password=$WIFI_PASSWD&wifi_channel=$WIFI_CHANNEL&connection_type=$WAN_CONNECTION_TYPE&ntp=$NTP_INFO&hardreset=$HARDRESET&upgfirm=$UPGRADEFIRMWARE"
  _url="https://$SERVER_ADDR/deviceinfo/syn/"
  _res=$(rest_flashman "$_url" "$_data") 

  if [ "$?" -eq 1 ]
  then
    log "FLASHMAN UPDATER" "Fail in Rest Flashman! Aborting..."
  else
    json_load "$_res"
    json_get_var _do_update do_update
    json_get_var _do_newprobe do_newprobe
    json_get_var _release_id release_id
    json_get_var _connection_type connection_type
    json_get_var _pppoe_user pppoe_user
    json_get_var _pppoe_password pppoe_password
    json_get_var _wifi_ssid wifi_ssid
    json_get_var _wifi_password wifi_password
    json_get_var _wifi_channel wifi_channel
    json_get_var _app_password app_password
    json_get_var _blocked_devices_length blocked_devices_length
    declare -a _blocked_devices
    json_select blocked_devices
    INDEX="1"  # json library starts indexing at 1
    while json_get_type TYPE $INDEX && [ "$TYPE" = string ]; do
      json_get_var _blocked_device $INDEX
      _blocked_devices["$((INDEX++))"]=_blocked_device
    done
    json_close_object

    if [ "$HARDRESET" == "1" ]
    then
      rm /root/hard_reset
    fi

    if [ "$UPGRADEFIRMWARE" == "1" ]
    then
      rm /root/upgrade_info
    fi

    if [ "$_do_newprobe" == "1" ]
    then
      log "FLASHMAN UPDATER" "Router Registred in Flashman Successfully!"
      #on a new probe, force a new registry in mqtt secret
      reset_mqtt_secret
    fi

    # send boot log information if boot is completed and probe is registred!
    if [ ! -e /tmp/boot_completed ]
    then
      log "FLASHMAN UPDATER" "Sending BOOT log"
      send_boot_log "boot"
      echo "0" > /tmp/boot_completed
    fi

    # Connection type update
    if [ "$_connection_type" != "$WAN_CONNECTION_TYPE" ]
    then
      if [ "$_connection_type" == "dhcp" ]
      then
        log "FLASHMAN UPDATER" "Updating connection type to DHCP ..."
        uci set network.wan.proto="dhcp"
        uci set network.wan.username=""
        uci set network.wan.password=""
        uci set network.wan.service=""
        uci commit network

        /etc/init.d/network restart

        # This will persist connection type between firmware upgrades
        echo "dhcp" > /root/custom_connection_type
      elif [ "$_connection_type" == "pppoe" ]
      then
        if [ "$_pppoe_user" != "" ] && [ "$_pppoe_password" != "" ]
        then
          log "FLASHMAN UPDATER" "Updating connection type to PPPOE ..."
          uci set network.wan.proto="pppoe"
          uci set network.wan.username="$_pppoe_user"
          uci set network.wan.password="$_pppoe_password"
          uci set network.wan.service="$FLM_WAN_PPPOE_SERVICE"
          uci commit network

          /etc/init.d/network restart

          # This will persist connection type between firmware upgrades
          echo "pppoe" > /root/custom_connection_type
        fi
      fi
      # Don't put anything outside here. _content_type may be corrupted
    fi

    # PPPoE update
    if [ "$WAN_CONNECTION_TYPE" == "pppoe" ]
    then
      if [ "$_pppoe_user" != "" ] && [ "$_pppoe_password" != "" ]
      then
        if [ "$_pppoe_user" != "$PPPOE_USER" ] || \
           [ "$_pppoe_password" != "$PPPOE_PASSWD" ]
        then
          log "FLASHMAN UPDATER" "Updating PPPoE ..."
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
          log "FLASHMAN UPDATER" "Updating Wireless ..."
          uci set wireless.@wifi-iface[0].ssid="$_wifi_ssid"
          uci set wireless.@wifi-iface[0].key="$_wifi_password"
          uci set wireless.radio0.channel="$_wifi_channel"
          #5Ghz
          if [ "$(uci get wireless.@wifi-device[1].disabled)" == "0" ]
          then
            uci set wireless.@wifi-iface[1].ssid="$_wifi_ssid"
            uci set wireless.@wifi-iface[1].key="$_wifi_password"
          fi
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
      log "FLASHMAN UPDATER" "Reflashing ..."
      # Execute firmware update
      run_reflash $SERVER_ADDR $_release_id
    fi
  fi
else
  log "FLASHMAN UPDATER" "Fail Authenticating device!"
fi
log "FLASHMAN UPDATER" "Done" 

