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
  json_cleanup
  json_init
  json_add_string "mqtt_secret" "$_tmp_mqtt_secret"
  json_add_string "wan_conn_type" "$_tmp_conn_type"
  json_add_string "pppoe_user" "$_tmp_pppoe_user"
  json_add_string "pppoe_pass" "$_tmp_pppoe_pass"
  json_add_string "flashapp_pass" "$_tmp_flashapp_pass"
  json_add_string "zabbix_send_data" "n"
  json_add_string "has_upgraded_version" "$_tmp_has_upgraded_version"
  json_add_string "hard_reset_info" "$_tmp_hard_reset_info"
  json_dump > /root/flashbox_config.json
  json_close_object

  ## Migration below usefull for versions older than 0.13.0

  # In this migration we can also update some fixed wifi parameters
  # that improves performance and were not present on older Flashbox versions
  # This will be replaced on z005 if it's the first boot after factory firmware
  uci set wireless.@wifi-device[0].noscan="1"
  uci set wireless.@wifi-device[0].country="BR"
  if [ "$(uci -q get wireless.@wifi-iface[1])" ]
  then
    uci set wireless.@wifi-device[1].noscan="1"
    uci set wireless.@wifi-device[1].country="BR"
  fi

  if [ -f /etc/wireless/mt7628/mt7628.dat ]
  then
    uci set wireless.@wifi-device[0].wifimode="9"
    uci set wireless.@wifi-device[0].ht_bsscoexist="0"
    uci set wireless.@wifi-device[0].bw="1"
    # 5GHz
    if [ "$(uci -q get wireless.@wifi-iface[1])" ]
    then
      uci set wireless.@wifi-device[1].wifimode="15"
      uci set wireless.@wifi-device[1].ht_bsscoexist="0"
      uci set wireless.@wifi-device[1].bw="2"
    fi
  fi
  uci commit wireless
fi

#Migrate wireless
SSID_VALUE=$(uci -q get wireless.@wifi-iface[0].ssid)
if [ "$SSID_VALUE" != "OpenWrt" ] && [ "$SSID_VALUE" != "LEDE" ] && [ -n "$SSID_VALUE" ]
then
  json_cleanup
  json_load_file /root/flashbox_config.json
  json_get_var _ssid_24 ssid_24
  if [ -z "$_ssid_24" ]
  then
    json_add_string ssid_24 "$(uci -q get wireless.@wifi-iface[0].ssid)"
    json_add_string password_24 "$(uci -q get wireless.@wifi-iface[0].key)"
    json_add_string channel_24 "$(uci -q get wireless.@wifi-device[0].channel)"
    json_add_string hwmode_24 "$(uci -q get wireless.@wifi-device[0].hwmode)"
    json_add_string htmode_24 "$(uci -q get wireless.@wifi-device[0].htmode)"
    json_add_string state_24 "1"

    SSID_VALUE=$(uci -q get wireless.@wifi-iface[1].ssid)
    if [ "$SSID_VALUE" != "OpenWrt" ] && [ "$SSID_VALUE" != "LEDE" ] && [ -n "$SSID_VALUE" ]
    then
      json_add_string ssid_50 "$(uci -q get wireless.@wifi-iface[1].ssid)"
      json_add_string password_50 "$(uci -q get wireless.@wifi-iface[1].key)"
      json_add_string channel_50 "$(uci -q get wireless.@wifi-device[1].channel)"
      json_add_string hwmode_50 "$(uci -q get wireless.@wifi-device[1].hwmode)"
      json_add_string htmode_50 "$(uci -q get wireless.@wifi-device[1].htmode)"
      json_add_string state_50 "1"
    fi
    json_dump > /root/flashbox_config.json
  fi
  json_close_object
fi

# Create temporary file to differentiate between a boot after a upgrade
echo "0" > /tmp/clean_boot
