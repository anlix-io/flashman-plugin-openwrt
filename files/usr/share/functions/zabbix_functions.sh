#!/bin/sh

. /usr/share/flashman_init.conf
. /usr/share/libubox/jshn.sh
. /usr/share/functions/common_functions.sh

get_zabbix_send_data() {
  local _send
  json_cleanup
  json_load_file /root/flashbox_config.json
  json_get_var _send zabbix_send_data
  json_close_object

  echo "$_send"
}

get_zabbix_psk() {
  local _psk
  json_cleanup
  json_load_file /root/flashbox_config.json
  json_get_var _psk zabbix_psk
  json_close_object

  echo "$_psk"
}

get_zabbix_fqdn() {
  local _fqdn
  json_cleanup
  json_load_file /root/flashbox_config.json
  json_get_var _fqdn zabbix_fqdn
  json_close_object

  echo "$_fqdn"
}

# $1 - psk / $2 - fqdn / $3 - send_data
set_zabbix_params() {
  local _changed_params=0
  local _psk="$(get_zabbix_psk)"
  local _fqdn="$(get_zabbix_fqdn)"
  local _send_data="$(get_zabbix_send_data)"
  json_cleanup
  json_load_file /root/flashbox_config.json
  # Check if psk changed
  if [ "$1" != "" ] && [ "$1" != "$_psk" ]
  then
    log "ZABBIX" "Updating zabbix PSK parameter"
    _psk="$1"
    json_add_string zabbix_psk "$1"
    echo -n "$1" > /etc/zabbix_agentd.psk
    _changed_params=1
  fi
  # Check if zabbix fqdn changed
  if [ "$2" != "" ] && [ "$2" != "$_fqdn" ]
  then
    log "ZABBIX" "Updating zabbix FQDN parameter"
    _fqdn="$2"
    json_add_string zabbix_fqdn "$2"
    sed -i 's/Server=.*/Server='"$2"'/' /etc/zabbix_agentd.conf
    sed -i 's/ServerActive=.*/ServerActive='"$2"':80/' /etc/zabbix_agentd.conf
    _changed_params=1
  fi
  if [ "$3" = "1" ] && { [ "$_send_data" != "y" ] || [ "$_changed_params" = "1" ]; }
  then
    # Properly restart zabbix service if was active and anything changed
    # or if was inactive and new values are valid
    if [ "$_psk" != "" ] && [ "$_fqdn" != "" ]
    then
      log "ZABBIX" "Starting zabbix agent"
      json_add_string zabbix_send_data "y"
      /etc/init.d/zabbix_agentd stop
      /etc/init.d/zabbix_agentd start
    else
      log "ZABBIX" "Stopping zabbix agent"
      /etc/init.d/zabbix_agentd stop
      json_add_string zabbix_send_data "n"
    fi
  else
    # Properly kill zabbix service
    log "ZABBIX" "Stopping zabbix agent"
    /etc/init.d/zabbix_agentd stop
    json_add_string zabbix_send_data "n"
  fi
}

check_zabbix_startup() {
  local _do_restart
  _do_restart="$1"

  if [ "$(get_zabbix_send_data)" = "y" ] && [ -f /etc/zabbix_agentd.psk ]
  then
    # Enable Zabbix
    /etc/init.d/zabbix_agentd enable
    if [ "$_do_restart" = "true" ]
    then
      /etc/init.d/zabbix_agentd restart
    else
      /etc/init.d/zabbix_agentd start
    fi
    log "ZABBIX" "Zabbix Enabled"
  else
    # Disable Zabbix
    /etc/init.d/zabbix_agentd stop
    /etc/init.d/zabbix_agentd disable
    log "ZABBIX" "Zabbix Disabled"
  fi
}

update_zabbix_params() {
  local _res
  local _retstatus
  local _success
  local _psk
  local _fqdn
  local _send_data

  if [ "$1" = "on" ]
  then
    _res=$(curl -s --tlsv1.2 --connect-timeout 5 --retry 1 \
           -H "Content-Type: application/json" -H "X-ANLIX-ID: $(get_mac)" \
           -H "X-ANLIX-SEC: $FLM_CLIENT_SECRET" \
           --data @- "https://$FLM_SVADDR/deviceinfo/get/measureconfig")
    _retstatus=$?
    if [ $_retstatus -eq 0 ]
    then
      json_load "$_res"
      json_get_var _success success
      if [ "$_success" = "1" ]
      then
        json_get_var _psk psk
        json_get_var _fqdn fqdn
        json_get_var _send_data is_active
        set_zabbix_params "$_psk" "$_fqdn" "$_send_data"
      else
        log "ZABBIX" "Error retrieving parameters from flashman"
      fi
      json_close_object
    else
      log "ZABBIX" "Failed to get parameters in flashman"
    fi
  elif [ "$1" = "off" ]
  then
    json_cleanup
    json_load_file /root/flashbox_config.json
    json_add_string zabbix_send_data "n"
    json_dump > /root/flashbox_config.json
    json_close_object
    /etc/init.d/zabbix_agentd stop
  fi
}
