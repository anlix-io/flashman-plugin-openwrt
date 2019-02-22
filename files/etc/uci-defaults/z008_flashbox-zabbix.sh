#!/bin/sh

. /usr/share/libubox/jshn.sh

json_cleanup
json_load_file /root/flashbox_config.json
json_get_var _zabbix_psk zabbix_psk
json_get_var _zabbix_fqdn zabbix_fqdn
json_close_object
if [ "$_zabbix_psk" != "" ]
then
  echo -n $_zabbix_psk > /etc/zabbix_agentd.psk
fi
if [ "$_zabbix_fqdn" != "" ]
then
  sed -i 's/Server=.*/Server='"$_zabbix_fqdn"'/' /etc/zabbix_agentd.conf
  sed -i 's/ServerActive=.*/ServerActive='"$_zabbix_fqdn"':80/' /etc/zabbix_agentd.conf
fi

exit 0
