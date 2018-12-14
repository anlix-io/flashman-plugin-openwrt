#!/bin/sh

. /usr/share/flashman_init.conf

LAN_ADDR="10.0.10.1"
wan_proto_value=$(uci get network.wan.proto)
custom_connection_type=$(cat /root/custom_connection_type || echo "")

# Configure WAN
uci set network.wan.proto="$FLM_WAN_PROTO"
uci set network.wan.mtu="$FLM_WAN_MTU"
# Configure LAN
uci set network.lan.ipaddr="$LAN_ADDR"
uci set network.lan.netmask="255.255.255.0"

uci set network.dmz=interface
uci set network.dmz.proto='static'
uci set network.dmz.netmask='255.255.255.0'
uci set network.dmz.ip6assign='60'
uci set network.dmz.ifname='@lan'
uci set network.dmz.ipaddr='192.168.43.1'

if [ "$FLM_WAN_PROTO" = "pppoe" ] && [ "$wan_proto_value" != "pppoe" ] && \
   [ "$custom_connection_type" != "dhcp" ]
then
  uci set network.wan.username="$FLM_WAN_PPPOE_USER"
  uci set network.wan.password="$FLM_WAN_PPPOE_PASSWD"
  uci set network.wan.service="$FLM_WAN_PPPOE_SERVICE"
fi
# Check custom wan type for pppoe
if [ "$custom_connection_type" = "pppoe" ]
then
  uci set network.wan.proto="$custom_connection_type"
  uci set network.wan.service="$FLM_WAN_PPPOE_SERVICE"
fi
# Check for custom pppoe credentials
if [ "$custom_connection_type" = "pppoe" ] && \
   [ -f  /root/custom_pppoe_user ] && [ -f  /root/custom_pppoe_password ]
then
  _custom_pppoe_user=$(cat /root/custom_pppoe_user)
  _custom_pppoe_password=$(cat /root/custom_pppoe_password)
  uci set network.wan.username="$_custom_pppoe_user"
  uci set network.wan.password="$_custom_pppoe_password"
fi

uci commit network

A=$(grep "$LAN_ADDR anlixrouter" /etc/hosts)
if [ ! "$A" ]
then
  echo "$LAN_ADDR anlixrouter" >> /etc/hosts
fi

exit 0
