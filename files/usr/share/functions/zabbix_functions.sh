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

set_zabbix_send_data() {
  json_cleanup
  json_load_file /root/flashbox_config.json
  json_add_string zabbix_send_data "$1"
  json_dump > /root/flashbox_config.json
  json_close_object
}

get_zabbix_psk() {
  local _psk
  json_cleanup
  json_load_file /root/flashbox_config.json
  json_get_var _psk zabbix_psk
  json_close_object

  echo "$_psk"
}

set_zabbix_psk() {
  json_cleanup
  json_load_file /root/flashbox_config.json
  json_add_string zabbix_psk "$1"
  json_dump > /root/flashbox_config.json
  json_close_object
  echo -n "$1" > /etc/zabbix_agentd.psk
}

get_zabbix_fqdn() {
  local _fqdn
  json_cleanup
  json_load_file /root/flashbox_config.json
  json_get_var _fqdn zabbix_fqdn
  json_close_object

  echo "$_fqdn"
}

set_zabbix_fqdn() {
  json_cleanup
  json_load_file /root/flashbox_config.json
  json_add_string zabbix_fqdn "$1"
  json_dump > /root/flashbox_config.json
  json_close_object
  sed -i 's/Server=.*/Server='"$1"'/' /etc/zabbix_agentd.conf
  sed -i 's/ServerActive=.*/ServerActive='"$1"':80/' /etc/zabbix_agentd.conf
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
        if [ "$_psk" != "" ] && [ "$_fqdn" != "" ] && [ "$_psk" != "$(get_zabbix_psk)" ] && [ "$_fqdn" != "$(get_zabbix_fqdn)" ]
        then
          log "ZABBIX" "Updating psk and fqdn parameters"
          /etc/init.d/zabbix_agentd stop
          set_zabbix_psk "$_psk"
          set_zabbix_fqdn "$_fqdn"
          set_zabbix_send_data "y"
          /etc/init.d/zabbix_agentd start
        else
          log "ZABBIX" "No change in psk or fqdn parameters"
        fi
      else
        log "ZABBIX" "Error retrieving parameters from flashman"
      fi
      json_close_object
    else
      log "ZABBIX" "Failed to get parameters in flashman"
    fi
  elif [ "$1" = "off" ]
  then
    set_zabbix_send_data "n"
    /etc/init.d/zabbix_agentd stop
  fi
}
