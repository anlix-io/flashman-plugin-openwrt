#!/bin/sh

generate_pwdiffs_realtek() {
	for i in `seq 70`; do printf 0; done;
	for i in `seq 10`; do printf $1; done;
	for i in `seq 42`; do printf 0; done
}

anlix_bootup_defaults() {
	local _PARAMS="$(strings /dev/mtd1ro)"

	ifconfig wlan0 up
	iwpriv wlan0 set_mib xcap=$(echo "$_PARAMS" | sed -n 's/^HW_WLAN1_11N_XCAP=//p')
	iwpriv wlan0 set_mib ther=$(echo "$_PARAMS" | sed -n 's/^HW_WLAN1_11N_THER=//p')
	iwpriv wlan0 set_mib pwrlevelCCK_A=$(echo "$_PARAMS" | sed -n 's/^HW_WLAN1_TX_POWER_CCK_A=//p')
	iwpriv wlan0 set_mib pwrlevelCCK_B=$(echo "$_PARAMS" | sed -n 's/^HW_WLAN1_TX_POWER_CCK_B=//p')
	iwpriv wlan0 set_mib pwrlevelHT40_1S_A=$(echo "$_PARAMS" | sed -n 's/^HW_WLAN1_TX_POWER_HT40_1S_A=//p')
	iwpriv wlan0 set_mib pwrlevelHT40_1S_B=$(echo "$_PARAMS" | sed -n 's/^HW_WLAN1_TX_POWER_HT40_1S_B=//p')
	iwpriv wlan0 set_mib pwrdiffHT40_2S=$(echo "$_PARAMS" | sed -n 's/^HW_WLAN1_TX_POWER_DIFF_HT40_2S=//p')
	iwpriv wlan0 set_mib pwrdiffHT20=$(echo "$_PARAMS" | sed -n 's/^HW_WLAN1_TX_POWER_DIFF_HT20=//p')
	iwpriv wlan0 set_mib pwrdiffOFDM=$(echo "$_PARAMS" | sed -n 's/^HW_WLAN1_TX_POWER_DIFF_OFDM=//p')
	ifconfig wlan0 down

	ifconfig wlan1 up
	iwpriv wlan1 set_mib xcap=$(echo "$_PARAMS" | sed -n 's/^HW_WLAN0_11N_XCAP=//p')
	iwpriv wlan1 set_mib ther=$(echo "$_PARAMS" | sed -n 's/^HW_WLAN0_11N_THER=//p')
	iwpriv wlan1 set_mib pwrlevel5GHT40_1S_A=$(echo "$_PARAMS" | sed -n 's/^HW_WLAN0_TX_POWER_5G_HT40_1S_A=//p')
	iwpriv wlan1 set_mib pwrlevel5GHT40_1S_B=$(echo "$_PARAMS" | sed -n 's/^HW_WLAN0_TX_POWER_5G_HT40_1S_B=//p')

	local _pwrdiff=$(echo "$_PARAMS" | sed -n 's/^HW_WLAN0_TX_POWER_DIFF_5G_20BW1S_OFDM1T_A=//p')
	iwpriv wlan1 set_mib pwrdiff_5G_20BW1S_OFDM1T_A=$(generate_pwdiffs_realtek $_pwrdiff)
	_pwrdiff=$(echo "$_PARAMS" | sed -n 's/^HW_WLAN0_TX_POWER_DIFF_5G_20BW1S_OFDM1T_B=//p')
	iwpriv wlan1 set_mib pwrdiff_5G_20BW1S_OFDM1T_B=$(generate_pwdiffs_realtek $_pwrdiff)
	_pwrdiff=$(echo "$_PARAMS" | sed -n 's/^HW_WLAN0_TX_POWER_DIFF_5G_40BW2S_20BW2S_A=//p')
	iwpriv wlan1 set_mib pwrdiff_5G_40BW2S_20BW2S_A=$(generate_pwdiffs_realtek $_pwrdiff)
	_pwrdiff=$(echo "$_PARAMS" | sed -n 's/^HW_WLAN0_TX_POWER_DIFF_5G_40BW2S_20BW2S_B=//p')
	iwpriv wlan1 set_mib pwrdiff_5G_40BW2S_20BW2S_B=$(generate_pwdiffs_realtek $_pwrdiff)
	ifconfig wlan1 down
}

get_custom_mac() {
	. /lib/functions/system.sh
	local _mac_address_tag=""
	local _p1

	_p1=$(mtd_get_mac_ascii config HW_NIC0_ADDR | awk '{print toupper($1)}')
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
		swconfig dev switch0 vlan 8 set ports '3 4 6'
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
		2) echo "3" ;;
		3) echo "0 1 2" ;;
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
