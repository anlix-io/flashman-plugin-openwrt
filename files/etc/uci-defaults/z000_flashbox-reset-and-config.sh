#!/bin/sh

. /usr/share/libubox/jshn.sh

# Reset blockscan rule
A=$(uci -X show firewall | grep "path='/etc/firewall.blockscan'" | \
    awk -F '.' '{ print "firewall."$2 }')
if [ "$A" ]
then
  uci delete $A
fi
# Reset ssh rule
A=$(uci -X show firewall | \
    grep "firewall\..*\.name='\(anlix-ssh\|custom-ssh\)'" | \
    awk -F '.' '{ print "firewall."$2 }')
if [ "$A" ]
then
  uci delete $A
fi
# Migrate old multiple files into single JSON file
# Files: /root/router_passwd, /root/mqtt_secret,
#        /root/custom_connection_type, /root/upgrade_info,
#        /root/custom_pppoe_user, /root/custom_pppoe_password
if [ ! -f /root/flashbox_config.json ]
then
  _tmp_mqtt_secret=""
  if [ -f /root/mqtt_secret ]
  then
    _tmp_mqtt_secret=$(cat /root/mqtt_secret)
    rm /root/mqtt_secret
  fi
  _tmp_conn_type=""
  if [ -f /root/custom_connection_type ]
  then
    _tmp_conn_type=$(cat /root/custom_connection_type)
    rm /root/custom_connection_type
  fi
  _tmp_pppoe_user=""
  if [ -f /root/custom_pppoe_user ]
  then
    _tmp_pppoe_user=$(cat /root/custom_pppoe_user)
    rm /root/custom_pppoe_user
  fi
  _tmp_pppoe_pass=""
  if [ -f /root/custom_pppoe_password ]
  then
    _tmp_pppoe_pass=$(cat /root/custom_pppoe_password)
    rm /root/custom_pppoe_password
  fi
  _tmp_flashapp_pass=""
  if [ -f /root/router_passwd ]
  then
    _tmp_flashapp_pass=$(cat /root/router_passwd)
    rm /root/router_passwd
  fi
  _tmp_has_upgraded_version="0"
  if [ -f /root/upgrade_info ]
  then
    _tmp_has_upgraded_version="1"
    rm /root/upgrade_info
  fi
  _tmp_hard_reset_info="0"
  if [ -f /root/hard_reset ]
  then
    _tmp_hard_reset_info="1"
    rm /root/hard_reset
  fi
  #
  # WARNING! No spaces or tabs inside the following string!
  #
  _flashbox_config_json="{\
'mqtt_secret': '$_tmp_mqtt_secret',\
'wan_conn_type': '$_tmp_conn_type',\
'pppoe_user': '$_tmp_pppoe_user',\
'pppoe_pass': '$_tmp_pppoe_pass',\
'flashapp_pass': '$_tmp_flashapp_pass',\
'zabbix_send_data': 'n',\
'has_upgraded_version': '$_tmp_has_upgraded_version',\
'hard_reset_info': '$_tmp_hard_reset_info'}"

  echo "$_flashbox_config_json" > /root/flashbox_config.json

  ## Migration below usefull for versions older than 0.13.0

  # In this migration we can also update some fixed wifi parameters
  # that improves performance and were not present on older Flashbox versions
  # This will be replaced on z005 if it's the first boot after factory firmware
  uci set wireless.@wifi-device[0].wifimode="9"
  uci set wireless.@wifi-device[0].noscan="1"
  uci set wireless.@wifi-device[0].ht_bsscoexist="0"
  uci set wireless.@wifi-device[0].bw="1"
  # 5GHz
  if [ "$(uci -q get wireless.@wifi-iface[1])" ]
  then
    uci set wireless.@wifi-device[1].wifimode="15"
    uci set wireless.@wifi-device[1].noscan="1"
    uci set wireless.@wifi-device[1].ht_bsscoexist="0"
    uci set wireless.@wifi-device[1].bw="2"
    uci set wireless.@wifi-device[1].country="BR"
  fi
  uci commit wireless
fi

# Create temporary file to differentiate between a boot after a upgrade
echo "0" > /tmp/clean_boot
