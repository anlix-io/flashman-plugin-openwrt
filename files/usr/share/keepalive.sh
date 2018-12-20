#!/bin/sh

. /usr/share/flashman_init.conf
. /usr/share/functions.sh
. /usr/share/libubox/jshn.sh
. /usr/share/functions/device_functions.sh
. /usr/share/functions/wireless_functions.sh

HARDWARE_VER=$(cat /tmp/sysinfo/model | awk '{ print toupper($3) }')
PPPOE_USER=""
PPPOE_PASSWD=""

_need_update=0
_cert_error=0
while true
do
  sleep 300

  _rand=$(head /dev/urandom | tr -dc "012345")
  _number=${_rand:0:1}

  if [ "$_number" -eq 3 ] || [ "$1" == "now" ]
  then
    # Get PPPoE data if available
    if [ "$WAN_CONNECTION_TYPE" == "pppoe" ]
    then
      PPPOE_USER=$(uci get network.wan.username)
      PPPOE_PASSWD=$(uci get network.wan.password)
    fi

    # Get WiFi data
    json_load $(get_wifi_local_config)
    json_get_var _local_ssid_24 local_ssid_24
    json_get_var _local_password_24 local_password_24
    json_get_var _local_channel_24 local_channel_24
    json_get_var _local_hwmode_24 local_hwmode_24
    json_get_var _local_htmode_24 local_htmode_24
    json_get_var _local_ssid_50 local_ssid_50
    json_get_var _local_password_50 local_password_50
    json_get_var _local_channel_50 local_channel_50
    json_get_var _local_hwmode_50 local_hwmode_50
    json_get_var _local_htmode_50 local_htmode_50
    json_close_object

    WAN_CONNECTION_TYPE=$(uci get network.wan.proto | awk '{ print tolower($1) }')

    log "KEEPALIVE" "Ping Flashman ..."
    #
    # WARNING! No spaces or tabs inside the following string!
    #
    _data="id=$(get_mac)&\
flm_updater=0&\
version=$ANLIX_PKG_VERSION&\
model=$(get_hardware_model)&\
model_ver=$HARDWARE_VER&\
release_id=$FLM_RELID&\
pppoe_user=$PPPOE_USER&\
pppoe_password=$PPPOE_PASSWD&\
wan_ip=$(get_wan_ip)&\
wifi_ssid=$_local_ssid_24&\
wifi_password=$_local_password_24&\
wifi_channel=$_local_channel_24&\
connection_type=$WAN_CONNECTION_TYPE&\
ntp=$(ntp_anlix)"
    _url="deviceinfo/syn/"
    _res=$(rest_flashman "$_url" "$_data")

    _retstatus=$?
    if [ $_retstatus -eq 0 ]
    then
      _cert_error=0
      json_load "$_res"
      json_get_var _do_update do_update
      json_get_var _do_newprobe do_newprobe
      json_get_var _mqtt_status mqtt_status
      json_close_object

      if [ "$_do_newprobe" = "1" ]
      then
        log "KEEPALIVE" "Router Registred in Flashman Successfully!"
        # On a new probe, force a new registry in mqtt secret
        reset_mqtt_secret > /dev/null
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
        # More than 7 checks (>20 min), force a firmware update
        log "KEEPALIVE" "Running update ..."
        sh /usr/share/flashman_update.sh
      fi

      if [ "$_mqtt_status" = "0" ]
      then
        # Check is mqtt is running
        mqttpid=$(pgrep anlix-mqtt)
        if [ "$mqttpid" ] && [ $mqttpid -gt 0 ]
        then
          log "KEEPALIVE" "MQTT not connected to Flashman! Restarting..."
          kill -9 $mqttpid
        fi
      fi
    elif [ $_retstatus -eq 2 ]
    then
      log "KEEPALIVE" "Fail in Flashman Certificate! Retry $_cert_error"
      # Certificate problems are related to desync dates
      # Wait NTP, or correct if we can...
      _cert_error=$(( _cert_error + 1 ))
      if [ $_cert_error -gt 7 ]
      then
        # More than 7 checks (>20 min), force a date update
        log "KEEPALIVE" "Try resync date with Flashman!"
        resync_ntp
        _cert_error=0
      fi
    else
      log "KEEPALIVE" "Fail in Rest Flashman! Aborting..."
    fi
  fi
done
