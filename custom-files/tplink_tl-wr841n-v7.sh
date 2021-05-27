#!/bin/sh

get_custom_hardware_model() {
	echo "TL-WR841ND"
}

get_custom_mac() {
	local _mac_address_tag=""
	local _p0
	_p0=$(awk '{print toupper($1)}' /sys/class/ieee80211/phy0/macaddress)

	if [ ! -z "$_p0" ]
	then
		_mac_address_tag=$_p0
	fi
	echo "$_mac_address_tag"
}

custom_switch_ports() {
	case $1 in
		1) echo "switch0" ;;
		2) echo "5" ;;
		3) echo "4 3 2 1" ;;
		4) echo "0" ;;
		5) echo "4" ;;
	esac
}

wan_lan_diff_ifaces() {
	echo "1"
}
