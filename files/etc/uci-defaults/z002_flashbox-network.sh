#!/bin/sh

. /usr/share/flashman_init.conf
. /usr/share/libubox/jshn.sh
. /usr/share/functions/network_functions.sh

_wan_proto_value=$(uci get network.wan.proto)

json_cleanup
json_load_file /root/flashbox_config.json
json_get_var _wan_conn_type wan_conn_type
json_get_var _pppoe_user pppoe_user
json_get_var _pppoe_pass pppoe_pass
json_get_var _lan_addr lan_addr
json_get_var _lan_netmask lan_netmask
json_get_var _lan_ipv6prefix lan_ipv6prefix
json_close_object


if [ "$_lan_addr" = "" ] || [ "$_lan_netmask" = "" ]
then
  _lan_addr="$FLM_LAN_SUBNET"
  _lan_netmask="$FLM_LAN_NETMASK"
fi

if [ "$_lan_ipv6prefix" = "" ]
then
  _lan_ipv6prefix="$FLM_LAN_IPV6_PREFIX"
fi

# Validate LAN gateway address
valid_ip "$_lan_addr"
_retstatus=$?
if [ $_retstatus -eq 1 ]
then
  # Invalid. Use default 10.0.10.1
  _lan_addr="10.0.10.1"
  _lan_netmask="24"
else
  _ipcalc_res="$(/bin/ipcalc.sh $_lan_addr $_lan_netmask 1)"

  _ipcalc_netmask=$(echo "$_ipcalc_res" | grep "PREFIX" | awk -F= '{print $2}')
  # Accepted netmasks: 24 to 26
  if [ $_ipcalc_netmask -lt 24 ] || [ $_ipcalc_netmask -gt 26 ]
  then
    # Invalid netmask. Use default 24
    _lan_netmask="24"
    _lan_addr="10.0.10.1"
  else
    # Valid netmask
    _lan_netmask="$_ipcalc_netmask"
    # Use first address available returned by ipcalc
    _ipcalc_addr=$(echo "$_ipcalc_res" | grep "START" | awk -F= '{print $2}')
    _lan_addr="$_ipcalc_addr"
  fi
fi

# Configure WAN
uci set network.wan.proto="$FLM_WAN_PROTO"
uci set network.wan.mtu="$FLM_WAN_MTU"
uci set network.wan.service="$FLM_WAN_PPPOE_SERVICE"
uci set network.wan.keepalive="60 3"
# Configure LAN
uci set network.lan.ipaddr="$_lan_addr"
uci set network.lan.netmask="$_lan_netmask"
uci set network.lan.ip6assign="$_lan_ipv6prefix"

uci set network.dmz=interface
uci set network.dmz.proto='static'
uci set network.dmz.netmask='24'
uci set network.dmz.ifname='@lan'
uci set network.dmz.ipaddr='192.168.43.1'
uci set network.dmz.ip6assign="$_lan_ipv6prefix"

# Check custom wan type
if [ "$_wan_conn_type" = "pppoe" ] || [ "$_wan_conn_type" = "dhcp" ]
then
  uci set network.wan.proto="$_wan_conn_type"
fi

if [ "$FLM_WAN_PROTO" = "pppoe" ] && [ "$_wan_proto_value" != "pppoe" ] && \
   [ "$_wan_conn_type" != "dhcp" ]
then
  uci set network.wan.username="$FLM_WAN_PPPOE_USER"
  uci set network.wan.password="$FLM_WAN_PPPOE_PASSWD"
fi
# Check for custom pppoe credentials
if [ "$_wan_conn_type" = "pppoe" ] && \
   [ "$_pppoe_user" != "" ] && [ "$_pppoe_pass" != "" ]
then
  uci set network.wan.username="$_pppoe_user"
  uci set network.wan.password="$_pppoe_pass"
fi
# Check if IPv6 enabled
if [ "$FLM_WAN_IPV6_ENABLED" == "y" ]
then
  uci set network.wan.ipv6="auto"
else
  uci set network.wan.ipv6="0"
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
