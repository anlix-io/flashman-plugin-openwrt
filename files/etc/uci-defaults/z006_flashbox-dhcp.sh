#!/bin/sh

. /usr/share/functions/network_functions.sh

A=$(uci get dhcp.@dnsmasq[0].interface)
if [ "$A" ]
then
  uci delete dhcp.@dnsmasq[0].interface
fi

uci add_list dhcp.@dnsmasq[0].interface='lan'
uci set dhcp.lan.leasetime="1h"

# Calculate DHCP start and limit
_ipcalc_res="$(/bin/ipcalc.sh $(get_lan_subnet) $(get_lan_netmask) 1 255)"
_addr_net=$(echo "$_ipcalc_res" | grep "NETWORK" | awk -F. '{print $4}')
_addr_end=$(echo "$_ipcalc_res" | grep "END" | awk -F. '{print $4}')
_addr_limit=$(( (_addr_end - _addr_net) / 2 ))
_addr_start=$(( _addr_end - _addr_limit ))

uci set dhcp.lan.start="$_addr_start"
uci set dhcp.lan.limit="$_addr_limit"
uci set dhcp.lan.force='1'

uci set dhcp.dmz=dhcp
uci set dhcp.dmz.interface='dmz'
uci set dhcp.dmz.dynamicdhcp='0'
uci set dhcp.dmz.leasetime='1h'
uci set dhcp.dmz.force='1'

uci commit dhcp

exit 0
