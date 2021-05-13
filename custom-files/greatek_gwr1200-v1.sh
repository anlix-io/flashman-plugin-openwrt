#!/bin/sh

anlix_bootup_defaults() {
	ifconfig wlan0 up
	iwpriv wlan0 set_mib xcap=35
	iwpriv wlan0 set_mib ther=0
	iwpriv wlan0 set_mib pwrlevelCCK_A=2c2c2c2c2c2c2c2c2c2d2d2d2d2d
	iwpriv wlan0 set_mib pwrlevelCCK_B=2929292b2b2b2b2b2b2b2b2b2b2b
	iwpriv wlan0 set_mib pwrlevelHT40_1S_A=2828282828282828282929292929
	iwpriv wlan0 set_mib pwrlevelHT40_1S_B=2525252727272727272727272727
	ifconfig wlan0 down

	ifconfig wlan1 up
	iwpriv wlan1 set_mib xcap=41
	iwpriv wlan1 set_mib ther=25
	iwpriv wlan1 set_mib pwrlevel5GHT40_1S_A=00000000000000000000000000000000000000000000000000000000000000000000002525252525252523232323232322222222222222222222232323232323242424242424242424242424242424242424242424242424242424242424242424242424242424242424222222222222232323232323232323232323232323232525252525252525252525252525252527272727272727272727272929292929292929292929292929292929292929292900000000000000000000000000000000000000
	iwpriv wlan1 set_mib pwrlevel5GHT40_1S_B=00000000000000000000000000000000000000000000000000000000000000000000002424242424242423232323232322222222222222222222222222222222252525252525252525252525252525252525252525252525252525252525252525252525252525252525232323232323232323232323232323232222222222222424242424242424242424242424242427272727272727272727272929292929292929292929292929292929292929292900000000000000000000000000000000000000
	iwpriv wlan1 set_mib pwrdiff_5G_20BW1S_OFDM1T_A=00000000000000000000000000000000000000000000000000000000000000000000001313131313131313131313131313131313131313131313131313131313020202020202020202020202020202020202020202020202020202020202020202020202020202021313131313131313131313131313131313131313131313131313131313131313131313131313131302020202020202020224242424242424242424242424242424242424242424242400000000000000000000000000000000000000
	iwpriv wlan1 set_mib pwrdiff_5G_20BW1S_OFDM1T_B=00000000000000000000000000000000000000000000000000000000000000000000002424242424242424242424242424242424242424242424242424242424131313131313131313131313131313131313131313131313131313131313131313131313131313130202020202020202020202020202020202020202020202020202020202020202020202020202020214141414141414141413131313131313131313131313131313131313131313131300000000000000000000000000000000000000
	iwpriv wlan1 set_mib pwrdiff_5G_80BW1S_160BW1S_A=0000000000000000000000000000000000000000000000000000000000000000000000d0d0d0d0d0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e000000000000000000000000000000000000000
	iwpriv wlan1 set_mib pwrdiff_5G_80BW1S_160BW1S_B=0000000000000000000000000000000000000000000000000000000000000000000000e0e0e0e0e0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d000000000000000000000000000000000000000
	ifconfig wlan1 down
}

get_custom_mac() {
	. /lib/functions/system.sh
	local _mac_address_tag=""
	local _p1

	_p1=$(mtd_get_mac_binary config 19 | awk '{print toupper($1)}')
	[ ! -z "$_p1" ] && _mac_address_tag=$_p1

	echo "$_mac_address_tag"
}

set_vlan_on_boot() {
	echo "1"
}

custom_switch_ports() {
	case $1 in 
		1) echo "switch0" ;;
		2) echo "0" ;;
		3) echo "1 2 3 4" ;;
		4) echo "6" ;;
		5) echo "4" ;;
	esac
}
