#!/bin/sh

. /usr/share/flashman_init.conf
. /usr/share/functions.sh
. /usr/share/libubox/jshn.sh

SERVER_ADDR="$FLM_SVADDR"
OPENWRT_VER=$(cat /etc/openwrt_version)
HARDWARE_MODEL=$(get_hardware_model)
HARDWARE_VER=$(cat /tmp/sysinfo/model | awk '{ print toupper($3) }')
SYSTEM_MODEL=$(get_system_model)
CLIENT_MAC=$(get_mac)
PPPOE_USER=""
PPPOE_PASSWD=""
WIFI_SSID=""
WIFI_PASSWD=""
WIFI_CHANNEL=""

_need_update=0
_cert_error=0
while true
do
  sleep 300

  _number=$(awk 'BEGIN{srand();print int(rand()*6) }')

  if [ "$_number" -eq 3 ] || [ "$1" == "now" ]
  then
    # Get PPPoE data if available
    if [ "$WAN_CONNECTION_TYPE" == "pppoe" ]
    then
      PPPOE_USER=$(uci get network.wan.username)
      PPPOE_PASSWD=$(uci get network.wan.password)
    fi

    # Get WiFi data if available
    if [ "$(uci get wireless.@wifi-device[0].disabled)" == "0" ] || [ "$SYSTEM_MODEL" == "MT7628AN" ]
    then
      WIFI_SSID=$(uci get wireless.@wifi-iface[0].ssid)
      WIFI_PASSWD=$(uci get wireless.@wifi-iface[0].key)
      WIFI_CHANNEL=$(uci get wireless.radio0.channel)
    fi

    #Get NTP status
    NTP_INFO=$(ntp_anlix)

    WAN_IP_ADDR=$(get_wan_ip)
    WAN_CONNECTION_TYPE=$(uci get network.wan.proto | awk '{ print tolower($1) }')

     log "KEEPALIVE" "Ping Flashman ..."
    _data="id=$CLIENT_MAC&flm_updater=0&version=$ANLIX_PKG_VERSION&model=$HARDWARE_MODEL&model_ver=$HARDWARE_VER&release_id=$FLM_RELID&pppoe_user=$PPPOE_USER&pppoe_password=$PPPOE_PASSWD&wan_ip=$WAN_IP_ADDR&wifi_ssid=$WIFI_SSID&wifi_password=$WIFI_PASSWD&wifi_channel=$WIFI_CHANNEL&connection_type=$WAN_CONNECTION_TYPE&ntp=$NTP_INFO"
    _url="https://$SERVER_ADDR/deviceinfo/syn/"
    _res=$(rest_flashman "$_url" "$_data") 

    _retstatus=$?
    if [ $_retstatus -eq 0 ]
    then
      _cert_error=0
      json_load "$_res"
      json_get_var _do_update do_update
      json_get_var _do_newprobe do_newprobe
      json_close_object

      if [ "$_do_newprobe" = "1" ]
      then
        log "KEEPALIVE" "Router Registred in Flashman Successfully!"
        #on a new probe, force a new registry in mqtt secret
        reset_mqtt_secret
        sh /usr/share/flashman_update.sh
      fi

      if [ "$_do_update" = "1" ]
      then
        _need_update=$(( _need_update + 1 ))
      else
        _need_update=0
      fi

      if [ $_need_update -gt 7 ]
      then
        #More than 7 checks (>20 min), force a firmware update
        log "KEEPALIVE" "Running update ..."                                                                                                                                          
        sh /usr/share/flashman_update.sh
      fi
    elif [ $_retstatus -eq 2 ]
    then
      log "KEEPALIVE" "Fail in Flashman Certificate! Retry $_cert_error"
      # Certificate problems are related to desync dates
      # Wait NTP, or correct if we can...
      _cert_error=$(( _cert_error + 1 ))
      if [ $_cert_error -gt 7 ]
      then
        #More than 7 checks (>20 min), force a date update
        log "KEEPALIVE" "Try resync date with Flashman!"                                                                                                                                          
        resync_ntp
        _cert_error=0
      fi
    else
      log "KEEPALIVE" "Fail in Rest Flashman! Aborting..."
    fi
  fi
done
