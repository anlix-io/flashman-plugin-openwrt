#!/bin/sh

get_custom_leds_blink() {
	echo "$(ls -d /sys/class/leds/*yellow*)"
}

set_switch_bridge_mode() {
	local _enable_bridge="$1"
	local _disable_lan_ports="$2"

	if [ "$_enable_bridge" = "y" ]
	then
		if [ "$_disable_lan_ports" = "y" ]
		then
			uci set network.@switch_vlan[0].ports='1 0t'
			uci set network.@switch_vlan[1].ports=''
		else
			uci set network.@switch_vlan[0].ports='1 2 0t'
			uci set network.@switch_vlan[1].ports=''
		fi
	else
		uci set network.@switch_vlan[0].ports='2 0t'
		uci set network.@switch_vlan[1].ports='1 0t'
	fi
}

custom_switch_ports() {
	case $1 in
		1) echo "switch0" ;;
		2) echo "1" ;;
		3) echo "2" ;;
		4) echo "0" ;;
		5) echo "1" ;;
	esac
}
