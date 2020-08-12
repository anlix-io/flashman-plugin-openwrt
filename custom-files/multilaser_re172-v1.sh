#!/bin/sh

anlix_bootup_defaults() {
	ifconfig wlan0 up
	iwpriv wlan0 set_mib xcap=35
	iwpriv wlan0 set_mib pwrlevelCCK_A=2929292828282828282828282828
	iwpriv wlan0 set_mib pwrlevelCCK_B=2b2b2b2a2a2a2a2a2a2a2a2a2a2a
	iwpriv wlan0 set_mib pwrlevelHT40_1S_A=2929292828282828282828282828
	iwpriv wlan0 set_mib pwrlevelHT40_1S_B=2b2b2b2a2a2a2a2a2a2a2a2a2a2a
	ifconfig wlan0 down

	echo 1 > /proc/sys/vm/panic_on_oom
}

get_custom_mac() {
	local _mac_address_tag=""
	local _p1

	_p1=$(awk '{print toupper($1)}' /sys/class/net/eth1/address)
	[ ! -z "$_p1" ] && _mac_address_tag=$_p1

	echo "$_mac_address_tag"
}

set_switch_bridge_mode_on_boot() {
	local _disable_lan_ports="$1"

	if [ "$_disable_lan_ports" = "y" ]
	then
		# eth0
		swconfig dev switch0 vlan 9 set ports ''
		# eth1
		swconfig dev switch0 vlan 8 set ports '4 6'
	else
		# eth0
		swconfig dev switch0 vlan 9 set ports ''
		# eth1
		swconfig dev switch0 vlan 8 set ports '0 1 2 3 4 6'
	fi
}

#Force a memory cleanup to avoid processor usage in network
anlix_force_clean_memory() {
	echo 3 > /proc/sys/vm/drop_caches
}

custom_wan_port() {
	[ $1 == 1 ] && echo "switch0" || echo "4"
}
