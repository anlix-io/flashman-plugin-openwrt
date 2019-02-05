#!/bin/sh

. /usr/share/flashman_init.conf
. /usr/share/libubox/jshn.sh
. /usr/share/functions/common_functions.sh

check_zabbix_startup() {
  local _do_restart
  _do_restart="$1"

  sed -i "s%ZABBIX-SERVER-ADDR%$ZBX_SVADDR%" /etc/zabbix_agentd.conf
  if [ "$ZBX_SEND_DATA" = "y" ] && [ -f /etc/zabbix_agentd.psk ]
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
  fi
}

update_zabbix_psk() {
  if [ "$ZBX_SEND_DATA" = "y" ]
  then
    local _psk_key
    local _zabbix_psk
    _psk_key="$1"

    if [ "$_psk_key" != "" ]
    then
      /etc/init.d/zabbix_agentd stop
      json_cleanup
      json_load_file /root/flashbox_config.json
      json_add_string zabbix_psk "$_psk_key"
      json_dump > /root/flashbox_config.json
      json_close_object
      echo -n $_psk_key > /etc/zabbix_agentd.psk
      /etc/init.d/zabbix_agentd start
    else
      /etc/init.d/zabbix_agentd stop
      json_cleanup
      json_load_file /root/flashbox_config.json
      json_get_var _zabbix_psk zabbix_psk
      if [ "$_zabbix_psk" != "" ]
      then
        json_add_string zabbix_psk ""
        json_dump > /root/flashbox_config.json
      fi
      json_close_object
      if [ -f /etc/zabbix_agentd.psk ]
      then
        rm /etc/zabbix_agentd.psk
      fi
    fi
  fi
}
