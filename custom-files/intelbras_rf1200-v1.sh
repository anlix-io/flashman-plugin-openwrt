#!/bin/sh

anlix_bootup_defaults() {
	ifconfig wlan0 up
	iwpriv wlan0 set_mib xcap=35
	iwpriv wlan0 set_mib ther=36
	iwpriv wlan0 set_mib pwrlevelCCK_A=2C2C2C2E2E2E2E2E2E2E2E2E2E2E
	iwpriv wlan0 set_mib pwrlevelCCK_B=2E2E2E3030303030303030303030
	iwpriv wlan0 set_mib pwrlevelHT40_1S_A=2626262828282828282828282828
	iwpriv wlan0 set_mib pwrlevelHT40_1S_B=2929292929292929292A2A2A2A2A
	iwpriv wlan0 set_mib pwrdiffHT40_2S=e0e0e0e0e0e0e0e0e0e0e0e0e0e0
	iwpriv wlan0 set_mib pwrdiffHT20=1111112222222222221111111111
	iwpriv wlan0 set_mib pwrdiffOFDM=2222222222222222222222222222
	ifconfig wlan0 down

	ifconfig wlan1 up
	iwpriv wlan1 set_mib xcap=28
	iwpriv wlan1 set_mib ther=23
	iwpriv wlan1 set_mib pwrlevel5GHT40_1S_A=00000000000000000000000000000000000000000000000000000000000000000000002727272727272727272727272727272727272727272727272727272727272727272727272727272727272727272727272727272727272727272727272727272727272727272727272727272727272727272727272727272727272727272727272727272727272727272727272725252525252525252526262626262626262626262626262626262626262626262600000000000000000000000000000000000000
	iwpriv wlan1 set_mib pwrlevel5GHT40_1S_B=00000000000000000000000000000000000000000000000000000000000000000000002828282828282828282828282828282828282828282828282828282828282828282828282828282828282828282828282828282828282828282828282828282828282828282828282828282828282828282828282828282828282828282828282828282828282828282828282824242424242424242424242424242424242424242424242424242424242424242400000000000000000000000000000000000000
	iwpriv wlan1 set_mib pwrdiff_5G_20BW1S_OFDM1T_A=2212121212121212121212121200
	iwpriv wlan1 set_mib pwrdiff_5G_20BW1S_OFDM1T_B=1212121212121212121212121200
	iwpriv wlan1 set_mib pwrdiff_5G_40BW2S_20BW2S_A=efefefefefefefefefefefefef00
	iwpriv wlan1 set_mib pwrdiff_5G_40BW2S_20BW2S_B=efefefefefefefefefefefefef00
	ifconfig wlan1 down
}

get_custom_mac() {
	. /lib/functions/system.sh
	local _mac_address_tag=""
	local _p1

	_p1=$(mtd_get_mac_ascii boot HW_NIC0_ADDR | awk '{print toupper($1)}')
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
		swconfig dev switch0 vlan 8 set ports '0 6'
	else
		# eth0
		swconfig dev switch0 vlan 9 set ports ''
		# eth1
		swconfig dev switch0 vlan 8 set ports '0 1 2 3 4 6'
	fi
}

custom_switch_ports() {
	case $1 in 
		1) echo "switch0" ;;
		2) echo "0" ;;
		3) echo "1 2 3 4" ;;
	esac
}

get_custom_leds_blink() {
	echo "$(ls -d /sys/class/leds/*blue*)"
}
