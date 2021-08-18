#!/bin/sh

anlix_bootup_defaults() {
	ifconfig wlan0 up
	iwpriv wlan0 set_mib xcap=32
	iwpriv wlan0 set_mib ther=34
	iwpriv wlan0 set_mib pwrlevelCCK_A=1616161919191919191B1B1B1B1B
	iwpriv wlan0 set_mib pwrlevelCCK_B=1010101313131313131515151515
	iwpriv wlan0 set_mib pwrlevelHT40_1S_A=1919191A1A1A1A1A1A1C1C1C1C1C
	iwpriv wlan0 set_mib pwrlevelHT40_1S_B=1414141515151515151616161616
	iwpriv wlan0 set_mib pwrdiffHT40_2S=0000000000000000000000000000
	iwpriv wlan0 set_mib pwrdiffHT20=0000001111111111112222222222
	iwpriv wlan0 set_mib pwrdiffOFDM=1111112222222222223333333333
	ifconfig wlan0 down

	ifconfig wlan1 up
	iwpriv wlan1 set_mib xcap=37
	iwpriv wlan1 set_mib ther=28
	iwpriv wlan1 set_mib pwrlevel5GHT40_1S_A=00000000000000000000000000000000000000000000000000000000000000000000001D1D1D1D1D1D1D1D1D1D1D1D1D1D1D1D1D1D1D1D1D1D1D1D1D1D1D1D1D1D1D1D1D1D1D1D1D1D1D1D1D1D1D1D1D1D1D1D1D1D1D1D1D1D1D1D1D1D1D1D1D1D1D1D1D1D1D1D1D1D1D1D1D1D1D1D1D1D1D1D1D1D1D1D1D1D
	iwpriv wlan1 set_mib pwrlevel5GHT40_1S_B=00000000000000000000000000000000000000000000000000000000000000000000001F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F
	iwpriv wlan1 set_mib pwrdiff_5G_20BW1S_OFDM1T_A=1212121212121212121212121212
	iwpriv wlan1 set_mib pwrdiff_5G_20BW1S_OFDM1T_B=1212121212121212121212121212
	iwpriv wlan1 set_mib pwrdiff_5G_40BW2S_20BW2S_A=0101010101010101010101010101
	iwpriv wlan1 set_mib pwrdiff_5G_40BW2S_20BW2S_B=0101010101010101010101010101
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

is_realtek() {
	echo "1"
}

custom_switch_ports() {
	case $1 in 
		1) echo "switch0" ;;
		2) echo "3" ;;
		3) echo "0 1 2" ;;
		4) echo "6" ;;
		5) echo "3" ;;
	esac
}

get_custom_leds_blink() {
	echo "$(ls -d /sys/class/leds/*blue*)"
}

custom_wifi_24_txpower(){
	echo "22"
}

custom_wifi_50_channels(){
	echo "40"
}
