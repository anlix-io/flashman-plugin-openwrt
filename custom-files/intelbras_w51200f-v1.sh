#!/bin/sh

anlix_bootup_defaults() {

	# Get all parameters needed
	# interface 1: 5G
	# interface 2: 2.4G
	local _parameters_24g="$(anlix-flash-utils \
2 reg_domain \
2 x_cap \
2 thermal \
2 tr_switch \
2 pa_type \
2 power_level_cck_a \
2 power_level_cck_b \
2 power_level_ht40_1s_a \
2 power_level_ht40_1s_b \
2 power_diff_ht40_2s \
2 power_diff_ht20 \
2 power_diff_ofdm \
2 tx_power_tssi_ht40_1s_a \
2 tx_power_tssi_ht40_1s_b \
2 tssi_enable)"

	local _parameters_5g="$(anlix-flash-utils \
1 reg_domain \
1 x_cap \
1 thermal \
1 tr_switch \
1 pa_type \
1 tx_power_5g_ht40_1s_a \
1 tx_power_5g_ht40_1s_b \
1 tx_power_diff_5g_ofdm \
1 tx_power_diff_5g_20bw1s_ofdm1t_a \
1 tx_power_diff_5g_40bw2s_20bw2s_a \
1 tx_power_diff_5g_80bw1s_160bw1s_a \
1 tx_power_diff_5g_80bw2s_160bw2s_a \
1 tx_power_diff_5g_20bw1s_ofdm1t_b \
1 tx_power_diff_5g_40bw2s_20bw2s_b \
1 tx_power_diff_5g_80bw1s_160bw1s_b \
1 tx_power_diff_5g_80bw2s_160bw2s_b \
1 tx_power_tssi_5g_ht40_1s_a \
1 tx_power_tssi_5g_ht40_1s_b \
1 tssi_enable)"

	if [ ! -z "$_parameters_24g" ] && [ ! -z "$_parameters_5g" ] && 
	[ -n "$(echo $_parameters_24g | grep '[ ERROR ]')" ] && 
	[ -n "$(echo $_parameters_5g | grep '[ ERROR ]')" ]
	then

		get_data 15 _parameter_24g $_parameters_24g
		get_data 19 _parameter_5g $_parameters_5g

		ifconfig wlan0 up
		iwpriv wlan0 set_mib regdomain=$_parameter_24g0
		iwpriv wlan0 set_mib xcap=$_parameter_24g1
		iwpriv wlan0 set_mib ther=$_parameter_24g2
		iwpriv wlan0 set_mib trswitch=$_parameter_24g3
		iwpriv wlan0 set_mib pa_type=$_parameter_24g4
		iwpriv wlan0 set_mib pwrlevelCCK_A=$_parameter_24g5
		iwpriv wlan0 set_mib pwrlevelCCK_B=$_parameter_24g6
		iwpriv wlan0 set_mib pwrlevelHT40_1S_A=$_parameter_24g7
		iwpriv wlan0 set_mib pwrlevelHT40_1S_B=$_parameter_24g8
		iwpriv wlan0 set_mib pwrdiffHT40_2S=$_parameter_24g9
		iwpriv wlan0 set_mib pwrdiffHT20=$_parameter_24g10
		iwpriv wlan0 set_mib pwrdiffOFDM=$_parameter_24g11
		iwpriv wlan0 set_mib pwrlevel_TSSIHT40_1S_A=$_parameter_24g12
		iwpriv wlan0 set_mib pwrlevel_TSSIHT40_1S_B=$_parameter_24g13
		iwpriv wlan0 set_mib tssi_enable=$_parameter_24g14
		ifconfig wlan0 down

		ifconfig wlan1 up
		iwpriv wlan1 set_mib txbf=1
		iwpriv wlan1 set_mib regdomain=$_parameter_5g0
		iwpriv wlan1 set_mib xcap=$_parameter_5g1
		iwpriv wlan1 set_mib ther=$_parameter_5g2
		iwpriv wlan1 set_mib trswitch=$_parameter_5g3
		iwpriv wlan1 set_mib pa_type=$_parameter_5g4
		iwpriv wlan1 set_mib pwrlevel5GHT40_1S_A=$_parameter_5g5
		iwpriv wlan1 set_mib pwrlevel5GHT40_1S_B=$_parameter_5g6
		iwpriv wlan1 set_mib pwrdiff5GOFDM=$_parameter_5g7
		iwpriv wlan1 set_mib pwrdiff_5G_20BW1S_OFDM1T_A=$_parameter_5g8
		iwpriv wlan1 set_mib pwrdiff_5G_40BW2S_20BW2S_A=$_parameter_5g9
		iwpriv wlan1 set_mib pwrdiff_5G_80BW1S_160BW1S_A=$_parameter_5g10
		iwpriv wlan1 set_mib pwrdiff_5G_80BW2S_160BW2S_A=$_parameter_5g11
		iwpriv wlan1 set_mib pwrdiff_5G_20BW1S_OFDM1T_B=$_parameter_5g12
		iwpriv wlan1 set_mib pwrdiff_5G_40BW2S_20BW2S_B=$_parameter_5g13
		iwpriv wlan1 set_mib pwrdiff_5G_80BW1S_160BW1S_B=$_parameter_5g14
		iwpriv wlan1 set_mib pwrdiff_5G_80BW2S_160BW2S_B=$_parameter_5g15
		iwpriv wlan1 set_mib pwrlevel_TSSI5GHT40_1S_A=$_parameter_5g16
		iwpriv wlan1 set_mib pwrlevel_TSSI5GHT40_1S_B=$_parameter_5g17
		iwpriv wlan1 set_mib tssi_enable=$_parameter_5g18
		ifconfig wlan1 down

	else

		ifconfig wlan0 up
		iwpriv wlan0 set_mib xcap=0
		iwpriv wlan0 set_mib ther=27
		iwpriv wlan0 set_mib pwrlevelCCK_A=5c5c5c5c5c5c5c5c5c5c5c5c5c5c
		iwpriv wlan0 set_mib pwrlevelCCK_B=5353535353535353535353535353
		iwpriv wlan0 set_mib pwrlevelHT40_1S_A=6464646363636363635d5d5d5d5d
		iwpriv wlan0 set_mib pwrlevelHT40_1S_B=5c5c5c5e5e5e5e5e5e5a5a5a5a5a
		iwpriv wlan0 set_mib pwrdiffHT40_2S=0000000000000000000000000000
		iwpriv wlan0 set_mib pwrdiffHT20=adadadadadadadadadadadadadad
		iwpriv wlan0 set_mib pwrdiffOFDM=c9c9c9c9c9c9c9c9c9c9c9c9c9c9
		iwpriv wlan0 set_mib pwrlevel_TSSIHT40_1S_A=0e0e0e1111111111111a1a1a1a1a
		iwpriv wlan0 set_mib pwrlevel_TSSIHT40_1S_B=1919190f0f0f0f0f0f0c0c0c0c0c
		ifconfig wlan0 down

		ifconfig wlan1 up
		iwpriv wlan1 set_mib txbf=1
		iwpriv wlan1 set_mib xcap=65
		iwpriv wlan1 set_mib ther=33
		iwpriv wlan1 set_mib pwrlevel5GHT40_1S_A=00000000000000000000000000000000000000000000000000000000000000000000005757575757555555555555555555555555555555555555555555555555505050505050505050505050505050505050505050505050505050505050505050505050505050505050505050505050505050505050505050505050505050505050505050505050505050505050505054545454545454545454545454545454545454545454545454545454545454545400000000000000000000000000000000000000
		iwpriv wlan1 set_mib pwrlevel5GHT40_1S_B=000000000000000000000000000000000000000000000000000000000000000000000054545454544f4f4f4f4f4f4f4f4f4f4f4f4f4f4f4f4f4f4f4f4f4f4f4f50505050505050505050505050505050505050505050505050505050505050505050505050505050505050505050505050505050505050505050505050505050505050505050505050505050505050505a5a5a5a5a5a5a5a5a5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b00000000000000000000000000000000000000
		iwpriv wlan1 set_mib pwrdiff5GOFDM=000000000000000000000000000000000000000000000000000000000000000000000010101010101010101010101010101010101010101010101010101010100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000dfdfdfdfdfdfdfdfdfdfdfdfdfdfdfdfdfdfdfdfdfdfdfdfdfdfdfdfdfdfdfdfdf00000000000000000000000000000000000000
		iwpriv wlan1 set_mib pwrdiff_5G_80BW1S_160BW1S_A=00000000000000000000000000000000000000000000000000000000000000000000002020202020202020202020202030303030303030303030303030303030000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010101010101010101010101010101010101010101010101010101010101010101000000000000000000000000000000000000000
		iwpriv wlan1 set_mib pwrdiff_5G_80BW1S_160BW1S_B=00000000000000000000000000000000000000000000000000000000000000000000003030303030303030303030303050505050505050505050505050505050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010101010101010101010101010101010100000000000000000000000000000000000000000000000000000000000000000000000
		iwpriv wlan1 set_mib pwrlevel_TSSI5GHT40_1S_A=00000000000000000000000000000000000000000000000000000000000000000000001212121212131313131313131300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000015151515151515151515151515151515150000000000000000000000000000000000000000000000000000000000000000000000
		iwpriv wlan1 set_mib pwrlevel_TSSI5GHT40_1S_B=00000000000000000000000000000000000000000000000000000000000000000000000f0f0f0f0f121212121212121200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000012121212121212121213131313131313130000000000000000000000000000000000000000000000000000000000000000000000
		ifconfig wlan1 down

	fi
}

get_custom_mac() {
	. /lib/functions/system.sh
	local _mac_address_tag=""
	local _p1

	_p1=$(mtd_get_mac_binary config 7 | awk '{print toupper($1)}')
	[ ! -z "$_p1" ] && _mac_address_tag=$_p1

	echo "$_mac_address_tag"
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
