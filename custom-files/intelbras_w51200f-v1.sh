#!/bin/sh

anlix_bootup_defaults() {
	ifconfig wlan0 up
	iwpriv wlan0 set_mib xcap=0
	iwpriv wlan0 set_mib ther=25
	iwpriv wlan0 set_mib pwrlevelCCK_A=5b5b5b5a5a5a5a5a5a5353535353
	iwpriv wlan0 set_mib pwrlevelCCK_B=4f4f4f4b4b4b4b4b4b4949494949
	iwpriv wlan0 set_mib pwrlevelHT40_1S_A=6464646464646464645e5e5e5e5e
	iwpriv wlan0 set_mib pwrlevelHT40_1S_B=5c5c5c5858585858585454545454
	iwpriv wlan0 set_mib pwrdiffHT40_2S=0000000000000000000000000000
	iwpriv wlan0 set_mib pwrdiffHT20=dddddddddddddddddddddddddddd
	iwpriv wlan0 set_mib pwrdiffOFDM=bcbcbcbcbcbcbcbcbcbcbcbcbcbc
	iwpriv wlan0 set_mib pwrlevel_TSSIHT40_1S_A=2121211e1e1e1e1e1e2121212121
    iwpriv wlan0 set_mib pwrlevel_TSSIHT40_1S_B=1717171b1b1b1b1b1b1e1e1e1e1e
	ifconfig wlan0 down

	ifconfig wlan1 up
	iwpriv wlan1 set_mib xcap=69
	iwpriv wlan1 set_mib ther=28
	iwpriv wlan1 set_mib pwrlevel5GHT40_1S_A=00000000000000000000000000000000000000000000000000000000000000000000004343434343444444444444444444444444444444444444444444444444000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000044444444444444444441414141414141414141414141414141414141414141414100000000000000000000000000000000000000
	iwpriv wlan1 set_mib pwrlevel5GHT40_1S_B=00000000000000000000000000000000000000000000000000000000000000000000004141414141434343434343434343434343434343434343434343434343000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000042424242424242424241414141414141414141414141414141414141414141414100000000000000000000000000000000000000
	iwpriv wlan1 set_mib pwrdiff_5G_20BW1S_OFDM1T_A=00000000000000000000000000000000000000000000000000000000000000000000000e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f00000000000000000000000000000000000000
	iwpriv wlan1 set_mib pwrdiff_5G_80BW1S_160BW1S_A=00000000000000000000000000000000000000000000000000000000000000000000001010101010101010101010101000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000020202020202020202020202020202020203030303030303030303030303030303000000000000000000000000000000000000000
	iwpriv wlan1 set_mib pwrdiff_5G_80BW1S_160BW1S_B=000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000020202020202020202020202020202020202020202020202020202020202020202000000000000000000000000000000000000000
	iwpriv wlan1 set_mib pwrlevel_TSSI5GHT40_1S_A=000000000000000000000000000000000000000000000000000000000000000000000040404040403c3c3c3c3c3c3c3c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000036363636363636363639393939393939390000000000000000000000000000000000000000000000000000000000000000000000
	iwpriv wlan1 set_mib pwrlevel_TSSI5GHT40_1S_B=00000000000000000000000000000000000000000000000000000000000000000000003c3c3c3c3c373737373737373700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000036363636363636363636363636363636360000000000000000000000000000000000000000000000000000000000000000000000
	ifconfig wlan1 down
}

get_custom_mac() {
	. /lib/functions/system.sh
	local _mac_address_tag=""
	local _p1

	_p1=$(mtd_get_mac_binary config 7 | awk '{print toupper($1)}')
	[ ! -z "$_p1" ] && _mac_address_tag=$_p1

	echo "$_mac_address_tag"
}

set_switch_bridge_mode_on_boot() {
	echo "1"
}

custom_switch_ports() {
	case $1 in 
		1) echo "switch0" ;;
		2) echo "0" ;;
		3) echo "1 2 3" ;;
		4) echo "6" ;;
		5) echo "3" ;;
	esac
}

custom_wifi_24_txpower(){
	echo "20"
}

custom_wifi_50_txpower(){
	echo "20"
}
