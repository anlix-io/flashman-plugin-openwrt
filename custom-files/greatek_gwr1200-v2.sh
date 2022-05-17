#!/bin/sh

anlix_bootup_defaults() {

	# Get all parameters needed
	# interface 1: 5G
	# interface 2: 2.4G
	local _parameters_24g="$(anlix-flash-utils \
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

		get_data 14 _parameter_24g $_parameters_24g
		get_data 18 _parameter_5g $_parameters_5g

		ifconfig wlan0 up
		iwpriv wlan0 set_mib regdomain=1
		iwpriv wlan0 set_mib xcap=$_parameter_24g0
		iwpriv wlan0 set_mib ther=$_parameter_24g1
		iwpriv wlan0 set_mib trswitch=$_parameter_24g2
		iwpriv wlan0 set_mib pa_type=$_parameter_24g3
		iwpriv wlan0 set_mib pwrlevelCCK_A=$_parameter_24g4
		iwpriv wlan0 set_mib pwrlevelCCK_B=$_parameter_24g5
		iwpriv wlan0 set_mib pwrlevelHT40_1S_A=$_parameter_24g6
		iwpriv wlan0 set_mib pwrlevelHT40_1S_B=$_parameter_24g7
		iwpriv wlan0 set_mib pwrdiffHT40_2S=$_parameter_24g8
		iwpriv wlan0 set_mib pwrdiffHT20=$_parameter_24g9
		iwpriv wlan0 set_mib pwrdiffOFDM=$_parameter_24g10
		iwpriv wlan0 set_mib pwrlevel_TSSIHT40_1S_A=$_parameter_24g11
		iwpriv wlan0 set_mib pwrlevel_TSSIHT40_1S_B=$_parameter_24g12
		iwpriv wlan0 set_mib tssi_enable=$_parameter_24g13
		ifconfig wlan0 down

		ifconfig wlan1 up
		iwpriv wlan1 set_mib regdomain=1
		iwpriv wlan1 set_mib xcap=$_parameter_5g0
		iwpriv wlan1 set_mib ther=$_parameter_5g1
		iwpriv wlan1 set_mib trswitch=$_parameter_5g2
		iwpriv wlan1 set_mib pa_type=$_parameter_5g3
		iwpriv wlan1 set_mib pwrlevel5GHT40_1S_A=$_parameter_5g4
		iwpriv wlan1 set_mib pwrlevel5GHT40_1S_B=$_parameter_5g5
		iwpriv wlan1 set_mib pwrdiff5GOFDM=$_parameter_5g6
		iwpriv wlan1 set_mib pwrdiff_5G_20BW1S_OFDM1T_A=$_parameter_5g7
		iwpriv wlan1 set_mib pwrdiff_5G_40BW2S_20BW2S_A=$_parameter_5g8
		iwpriv wlan1 set_mib pwrdiff_5G_80BW1S_160BW1S_A=$_parameter_5g9
		iwpriv wlan1 set_mib pwrdiff_5G_80BW2S_160BW2S_A=$_parameter_5g10
		iwpriv wlan1 set_mib pwrdiff_5G_20BW1S_OFDM1T_B=$_parameter_5g11
		iwpriv wlan1 set_mib pwrdiff_5G_40BW2S_20BW2S_B=$_parameter_5g12
		iwpriv wlan1 set_mib pwrdiff_5G_80BW1S_160BW1S_B=$_parameter_5g13
		iwpriv wlan1 set_mib pwrdiff_5G_80BW2S_160BW2S_B=$_parameter_5g14
		iwpriv wlan1 set_mib pwrlevel_TSSI5GHT40_1S_A=$_parameter_5g15
		iwpriv wlan1 set_mib pwrlevel_TSSI5GHT40_1S_B=$_parameter_5g16
		iwpriv wlan1 set_mib tssi_enable=$_parameter_5g17
		ifconfig wlan1 down

	else
		ifconfig wlan0 up
		iwpriv wlan0 set_mib xcap=30
		iwpriv wlan0 set_mib ther=32
		iwpriv wlan0 set_mib pwrlevelCCK_A=57555452504f4d4d4d4d4d4d4d4d
		iwpriv wlan0 set_mib pwrlevelCCK_B=61616060605f5f5e5d5c5b5a5959
		iwpriv wlan0 set_mib pwrlevelHT40_1S_A=515151504e4d4d4d4c4c4c4c4c4c
		iwpriv wlan0 set_mib pwrlevelHT40_1S_B=5f5f5f5e5d5c5b5b5a5a59595959
		iwpriv wlan0 set_mib pwrdiffHT40_2S=fdfdfdfdfdfdfdfdfdfdfdfdfdfd
		iwpriv wlan0 set_mib pwrdiffHT20=00ffffff00011000110010000000
		iwpriv wlan0 set_mib pwrdiffOFDM=4433333344455444554454444444
		ifconfig wlan0 down

		ifconfig wlan1 up
		iwpriv wlan1 set_mib xcap=71
		iwpriv wlan1 set_mib ther=34
		iwpriv wlan1 set_mib pwrlevel5GHT40_1S_A=00000000000000000000000000000000000000000000000000000000000000000000005f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5e5e5e5e5e5e5e5e5d5d5d5d5d5d5d5d5c5c5c5c5c5c5c5c5b5b5b5b5b5b5b5b5a5a5a5a5a5a5a5a595959595959595a5a5a5a5b5b5b5c5c5d5d5e5e5f5e5e5d5d5c5c5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5b5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a00000000000000000000000000000000000000
		iwpriv wlan1 set_mib pwrlevel5GHT40_1S_B=00000000000000000000000000000000000000000000000000000000000000000000005d5d5d5d5d5d5d5d5d5d5d5e5e5f5f60616162626262616161616161616161616060606060606060606060605f5f5f5f5f5f5f5f5f5f5f5f5e5e5e5e5e5e5e5e5e5e5e5e5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5e5e5f5f606161626261616060605f5f5f5f5f5f5f5f6060606060606060606060606161616161616160605f5f5f5f5f5f5f5f5f5f5f5f5f5f5f5f00000000000000000000000000000000000000
		iwpriv wlan1 set_mib pwrdiff_5G_20BW1S_OFDM1T_A=00000000000000000000000000000000000000000000000000000000000000000000000202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020200000000000000000000000000000000000000
		iwpriv wlan1 set_mib pwrdiff_5G_20BW1S_OFDM1T_B=00000000000000000000000000000000000000000000000000000000000000000000000202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020200000000000000000000000000000000000000
		iwpriv wlan1 set_mib pwrdiff_5G_40BW2S_20BW2S_A=0000000000000000000000000000000000000000000000000000000000000000000000dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd00000000000000000000000000000000000000
		iwpriv wlan1 set_mib pwrdiff_5G_40BW2S_20BW2S_B=0000000000000000000000000000000000000000000000000000000000000000000000dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd00000000000000000000000000000000000000
		iwpriv wlan1 set_mib pwrdiff_5G_80BW1S_160BW1S_A=0000000000000000000000000000000000000000000000000000000000000000000000edededededededededededededededededededededededededededededededededededededededededededededededededededededededededededededededededededededededededededededededededededededededededededededededededededededededededededededededededededededededededededededededededededededededededededededed00000000000000000000000000000000000000
		iwpriv wlan1 set_mib pwrdiff_5G_80BW1S_160BW1S_B=0000000000000000000000000000000000000000000000000000000000000000000000edededededededededededededededededededededededededededededededededededededededededededededededededededededededededededededededededededededededededededededededededededededededededededededededededededededededededededededededededededededededededededededededededededededededededededededed00000000000000000000000000000000000000
		iwpriv wlan1 set_mib pwrdiff_5G_80BW2S_160BW2S_A=0000000000000000000000000000000000000000000000000000000000000000000000dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd00000000000000000000000000000000000000
		iwpriv wlan1 set_mib pwrdiff_5G_80BW2S_160BW2S_B=0000000000000000000000000000000000000000000000000000000000000000000000dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd00000000000000000000000000000000000000
		ifconfig wlan1 down
	fi
}

get_custom_mac() {
	. /lib/functions/system.sh
	local _mac_address_tag=""
	local _p1

	_p1=$(mtd_get_mac_binary config 19 | awk '{print toupper($1)}')
	[ ! -z "$_p1" ] && _mac_address_tag=$_p1

	echo "$_mac_address_tag"
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
