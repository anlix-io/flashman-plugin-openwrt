#!/bin/sh

get_custom_mac() {
	local _mac_address_tag=""
	local _p1

	_p1=$(awk '{print toupper($1)}' /sys/class/net/eth1/address)
	[ ! -z "$_p1" ] && _mac_address_tag=$_p1

	echo "$_mac_address_tag"
}

wan_lan_diff_ifaces() {
	echo "1"
}
