#!/bin/sh

get_custom_hardware_model() {
	echo "TL-WR741ND"
}

get_mac() {
	local _mac_address_tag=""
	local _p0
	_p0=$(awk '{print toupper($1)}' /sys/class/ieee80211/phy0/macaddress)

	if [ ! -z "$_p0" ]
	then
		_mac_address_tag=$_p0
	fi
	echo "$_mac_address_tag"
}
