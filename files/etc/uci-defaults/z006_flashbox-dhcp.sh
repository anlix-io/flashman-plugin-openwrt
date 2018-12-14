#!/bin/sh

A=$(uci get dhcp.@dnsmasq[0].interface)
if [ "$A" ]
then
  uci delete dhcp.@dnsmasq[0].interface
fi

uci add_list dhcp.@dnsmasq[0].interface='lan'
uci set dhcp.lan.leasetime="1h"

uci set dhcp.dmz=dhcp
uci set dhcp.dmz.interface='dmz'
uci set dhcp.dmz.dynamicdhcp='0'
uci set dhcp.dmz.leasetime='1h'

uci commit dhcp

exit 0
