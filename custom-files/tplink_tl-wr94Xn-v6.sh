#!/bin/sh

get_custom_leds_blink() {
	echo "$(ls -d /sys/class/leds/*orange*)"
}

#Force a memory cleanup to avoid processor usage in network
anlix_force_clean_memory() {
	echo 3 > /proc/sys/vm/drop_caches
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
