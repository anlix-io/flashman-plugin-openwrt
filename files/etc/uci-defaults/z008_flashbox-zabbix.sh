#!/bin/sh

. /usr/share/libubox/jshn.sh

json_cleanup
json_load_file /root/flashbox_config.json
json_get_var _zabbix_psk zabbix_psk
json_close_object
if [ "$_zabbix_psk" != "" ]
then
  echo -n $_zabbix_psk > /etc/zabbix_agentd.psk
fi

exit 0
