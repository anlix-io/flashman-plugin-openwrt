#!/bin/sh

. /usr/share/flashman_init.conf
. /usr/share/libubox/jshn.sh

_lan_addr="10.0.10.1"
_wan_proto_value=$(uci get network.wan.proto)

json_load_file /root/flashbox_config.json
json_get_var _wan_conn_type wan_conn_type
json_get_var _pppoe_user pppoe_user
json_get_var _pppoe_pass pppoe_pass
json_close_object

# Configure WAN
uci set network.wan.proto="$FLM_WAN_PROTO"
uci set network.wan.mtu="$FLM_WAN_MTU"
# Configure LAN
uci set network.lan.ipaddr="$_lan_addr"
uci set network.lan.netmask="255.255.255.0"

uci set network.dmz=interface
uci set network.dmz.proto='static'
uci set network.dmz.netmask='255.255.255.0'
uci set network.dmz.ip6assign='60'
uci set network.dmz.ifname='@lan'
uci set network.dmz.ipaddr='192.168.43.1'

if [ "$FLM_WAN_PROTO" = "pppoe" ] && [ "$_wan_proto_value" != "pppoe" ] && \
   [ "$_wan_conn_type" != "dhcp" ]
then
  uci set network.wan.username="$FLM_WAN_PPPOE_USER"
  uci set network.wan.password="$FLM_WAN_PPPOE_PASSWD"
  uci set network.wan.service="$FLM_WAN_PPPOE_SERVICE"
fi
# Check custom wan type for pppoe
if [ "$_wan_conn_type" = "pppoe" ]
then
  uci set network.wan.proto="$_wan_conn_type"
  uci set network.wan.service="$FLM_WAN_PPPOE_SERVICE"
fi
# Check for custom pppoe credentials
if [ "$_wan_conn_type" = "pppoe" ] && \
   [ "$_pppoe_user" != "" ] && [ "$_pppoe_pass" != "" ]
then
  uci set network.wan.username="$_pppoe_user"
  uci set network.wan.password="$_pppoe_pass"
fi

# Remove IPv6 ULA prefix to avoid phone issues
uci -q delete network.globals

uci commit network

A=$(grep "$_lan_addr anlixrouter" /etc/hosts)
if [ ! "$A" ]
then
  echo "$_lan_addr anlixrouter" >> /etc/hosts
fi

exit 0
