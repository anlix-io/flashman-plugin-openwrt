#!/bin/sh

. /usr/share/libubox/jshn.sh

json_cleanup
json_load_file /root/flashbox_config.json
json_get_var _zabbix_psk zabbix_psk
echo -n $_zabbix_psk > /etc/zabbix_agentd.psk
json_close_object

exit 0
