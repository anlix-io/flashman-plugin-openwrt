#!/bin/sh

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
  fi
  _tmp_conn_type=""
  if [ -f /root/custom_connection_type ]
  then
    _tmp_conn_type=$(cat /root/custom_connection_type)
  fi
  _tmp_pppoe_user=""
  if [ -f /root/custom_pppoe_user ]
  then
    _tmp_pppoe_user=$(cat /root/custom_pppoe_user)
  fi
  _tmp_pppoe_pass=""
  if [ -f /root/custom_pppoe_password ]
  then
    _tmp_pppoe_pass=$(cat /root/custom_pppoe_password)
  fi
  _tmp_flashapp_pass=""
  if [ -f /root/router_passwd ]
  then
    _tmp_flashapp_pass=$(cat /root/router_passwd)
  fi
  _tmp_upgrade_version_info=""
  if [ -f /root/upgrade_info ]
  then
    _tmp_upgrade_version_info=$(cat /root/upgrade_info)
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
'upgrade_version_info': '$_tmp_upgrade_version_info'}"

  echo "$_flashbox_config_json" > /root/flashbox_config.json
fi
