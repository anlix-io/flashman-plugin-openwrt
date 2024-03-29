#!/bin/sh

. /usr/share/flashman_init.conf
. /usr/share/libubox/jshn.sh
. /usr/share/functions/network_functions.sh
. /usr/share/functions/device_functions.sh
. /usr/share/functions/mesh_functions.sh

json_cleanup
json_load_file /root/flashbox_config.json
json_get_var _bridge_mode bridge_mode
json_get_var _bridge_disable_switch bridge_disable_switch
json_get_var _bridge_fix_ip bridge_fix_ip
json_get_var _bridge_fix_gateway bridge_fix_gateway
json_get_var _bridge_fix_dns bridge_fix_dns
json_get_var _wan_conn_type wan_conn_type
json_get_var _pppoe_user pppoe_user
json_get_var _pppoe_pass pppoe_pass
json_get_var _lan_addr lan_addr
json_get_var _lan_netmask lan_netmask
json_get_var _lan_ipv6prefix lan_ipv6prefix
json_get_var _enable_ipv6 enable_ipv6 
json_close_object

if [ -z "$_enable_ipv6" ]
then
	if [ "$FLM_WAN_IPV6_ENABLED" = "y" ]
	then
		_enable_ipv6="1"
	else
		_enable_ipv6="0"
	fi
fi

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
	eval "$_ipcalc_res"

	_ipcalc_netmask="$PREFIX"
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
		_ipcalc_addr="$START"
		_lan_addr="$_ipcalc_addr"
	fi
fi

# Configure WAN
uci set network.wan.proto="$FLM_WAN_PROTO"
uci set network.wan.mtu="$FLM_WAN_MTU"
uci set network.wan.service="$FLM_WAN_PPPOE_SERVICE"
uci set network.wan.vendorid="ANLIXAP"
uci set network.wan.keepalive="60 3"
# Configure LAN
uci set network.lan.ipaddr="$_lan_addr"
uci set network.lan.netmask="$_lan_netmask"
uci set network.lan.ip6assign="$_lan_ipv6prefix"
uci set network.lan.igmp_snooping='1'
uci set network.lan.stp='1'

uci set network.dmz=interface
uci set network.dmz.proto='static'
uci set network.dmz.netmask='24'
uci set network.dmz.ifname='@lan'
uci set network.dmz.ipaddr='192.168.43.1'
uci set network.dmz.ipv6='0'

# Check custom wan type
if [ "$_wan_conn_type" = "pppoe" ] || [ "$_wan_conn_type" = "dhcp" ]
then
	uci set network.wan.proto="$_wan_conn_type"
fi

if { [ "$_wan_conn_type" = "" ] && [ "$FLM_WAN_PROTO" = "pppoe" ]; } || \
	 [ "$_wan_conn_type" = "pppoe" ];
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
if [ "$_enable_ipv6" = "1" ]
then
	enable_ipv6
else
	disable_ipv6
fi

# Remove IPv6 ULA prefix to avoid phone issues
uci -q delete network.globals

uci commit network

A=$(grep "$_lan_addr anlixrouter" /etc/hosts)
if [ ! "$A" ]
then
	echo "$_lan_addr anlixrouter" >> /etc/hosts
fi

# Check if bridge mode should be enabled
if [ "$_bridge_mode" = "y" ]
then
	enable_bridge_mode "n" "n" "$_bridge_disable_switch" "$_bridge_fix_ip" \
			"$_bridge_fix_gateway" "$_bridge_fix_dns"
fi

exit 0
