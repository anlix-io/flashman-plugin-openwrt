#!/bin/sh
# WARNING! This file may be replaced depending on the selected target!

. /usr/share/libubox/jshn.sh
. /usr/share/flashman_init.conf
. /lib/functions/system.sh
. /usr/share/functions/device_functions.sh
. /usr/share/functions/wireless_functions.sh

MAC_ADDR="$(get_mac)"
MAC_LAST_CHARS=$(echo $MAC_ADDR | awk -F: '{ print $5$6 }')
SSID_VALUE=$(uci -q get wireless.@wifi-iface[0].ssid)
SUFFIX_5="-5GHz"
IS_REALTEK="$(lsmod | grep rtl8192cd)"

json_cleanup
json_load_file /root/flashbox_config.json
json_get_var _mesh_mode mesh_mode
json_get_var _mesh_master mesh_master
json_get_var _ssid_24 ssid_24
json_get_var _password_24 password_24
json_get_var _channel_24 channel_24
json_get_var _htmode_24 htmode_24
json_get_var _state_24 state_24
json_get_var _txpower_24 txpower_24 "100"
json_get_var _hidden_24 hidden_24 "0"
if [ "$(is_5ghz_capable)" == "1" ]
then
	json_get_var _ssid_50 ssid_50
	json_get_var _password_50 password_50
	json_get_var _channel_50 channel_50
	json_get_var _htmode_50 htmode_50
	json_get_var _state_50 state_50
	json_get_var _txpower_50 txpower_50 "100"
	json_get_var _hidden_50 hidden_50 "0"
fi
json_close_object

[ ! "$_mesh_mode" ] && _mesh_mode="0"

if [ -z "$_ssid24" ]
then
	#use defaults
	[ "$FLM_SSID_SUFFIX" == "none" ] && setssid="$FLM_SSID" || setssid="$FLM_SSID$MAC_LAST_CHARS"
	# Wireless password cannot be empty or have less than 8 chars
	if [ "$FLM_PASSWD" == "" ] || [ $(echo "$FLM_PASSWD" | wc -m) -lt 9 ]
	then
		FLM_PASSWD=$(echo $MAC_ADDR | sed -e "s/://g")
	fi

	_ssid_24=$setssid
	_password_24="$FLM_PASSWD"
	_channel_24="$FLM_24_CHANNEL"
	_htmode_24="$([ "$FLM_24_BAND" = "HT40" ] && echo "HT40" || echo "HT20")"
	_state_24="1"
	_txpower_24="100"
	_hidden_24="0"

	_ssid_50="$setssid$SUFFIX_5"
	_password_50="$FLM_PASSWD"
	_channel_50="$FLM_50_CHANNEL"
	_htmode_50="$([ "$(is_5ghz_vht)" ] && echo "VHT80" || echo "HT40")"
	_state_50="1"
	_txpower_50="100"
	_hidden_50="0"
fi

DEFAULT_24_CHANNELS="1 6 11 3 9 2 4 5 7 8 10"
DEFAULT_50_CHANNELS="36 40 44 153 157 161"

if [ "$(type -t custom_wifi_24_channels)" ]
then
	DEFAULT_24_CHANNELS="$(custom_wifi_24_channels)"
	[ "$(echo $DEFAULT_24_CHANNELS|grep -c ' ')" = 0 ] && _channel_24=$DEFAULT_24_CHANNELS
fi

if [ "$(type -t custom_wifi_50_channels)" ] 
then
	DEFAULT_50_CHANNELS="$(custom_wifi_50_channels)"
	[ "$(echo $DEFAULT_50_CHANNELS|grep -c ' ')" = 0 ] && _channel_50=$DEFAULT_50_CHANNELS
fi

_phy0=$(get_radio_phy "0")
if [ "$(get_phy_type $_phy0)" -eq "2" ]
then
	# 2.4 Radio is always first radio
	uci rename wireless.radio0=radiotmp
	uci rename wireless.radio1=radio0
	uci rename wireless.radiotmp=radio1
	uci rename wireless.default_radio0=default_radiotmp
	uci rename wireless.default_radio1=default_radio0
	uci rename wireless.default_radiotmp=default_radio1
	uci set wireless.default_radio0.device='radio0'
	uci set wireless.default_radio1.device='radio1'
	uci reorder wireless.radio0=0
	uci reorder wireless.default_radio0=1
	uci reorder wireless.radio1=2
	uci reorder wireless.default_radio1=3
fi

uci set wireless.radio0.txpower="$(convert_txpower "24" "$_channel_24" "$_txpower_24")"
uci set wireless.radio0.htmode="$_htmode_24"
uci set wireless.radio0.noscan="0"
[ "$_htmode_24" = "HT40" ] && uci set wireless.radio0.noscan="1"
uci set wireless.radio0.country="BR"
uci set wireless.radio0.channel="$_channel_24"
uci set wireless.radio0.channels="$DEFAULT_24_CHANNELS"
uci set wireless.radio0.disabled='0'
uci set wireless.default_radio0.disabled="$([ "$_state_24" = "1" ] && echo "0" || echo "1")"
uci set wireless.default_radio0.ifname='wlan0'
uci set wireless.default_radio0.ssid="$_ssid_24"
uci set wireless.default_radio0.encryption="$([ "$(grep RTL8196E /proc/cpuinfo)" ] && echo "psk2+tkip+ccmp" || echo "psk2")"
uci set wireless.default_radio0.key="$_password_24"
uci set wireless.default_radio0.hidden="$_hidden_24"
[ "$(type -t hostapd_cli)" ] && change_wps_state "0" "1"
[ "$IS_REALTEK" ] && uci set wireless.default_radio0.macaddr="$(macaddr_add $MAC_ADDR -1)"

if [ "$(is_5ghz_capable)" == "1" ]
then
	uci set wireless.radio1.txpower="$(convert_txpower "50" "$_channel_50" "$_txpower_50")"
	uci set wireless.radio1.channel="$_channel_50"
	uci set wireless.radio1.channels="$DEFAULT_50_CHANNELS"
	uci set wireless.radio1.country="BR"
	uci set wireless.radio1.htmode="$_htmode_50"
	uci set wireless.radio1.noscan="1"
	uci set wireless.radio1.disabled='0'
	uci set wireless.default_radio1.disabled="$([ "$_state_50" = "1" ] && echo "0" || echo "1")"
	uci set wireless.default_radio1.ifname='wlan1'
	uci set wireless.default_radio1.ssid="$_ssid_50"
	uci set wireless.default_radio1.encryption="psk2"
	uci set wireless.default_radio1.key="$_password_50"
	uci set wireless.default_radio1.hidden="$_hidden_50"
	[ "$(type -t hostapd_cli)" ] && change_wps_state "1" "1"
	[ "$IS_REALTEK" ] && uci set wireless.default_radio1.macaddr="$(macaddr_add $MAC_ADDR -2)"
fi

if [ "$_mesh_mode" -gt "0" ]
then
	if [ -z "$_mesh_master" ]
	then
		set_mesh_master_mode "$_mesh_mode"
	else
		set_mesh_slave_mode "$_mesh_mode" "$_mesh_master"
	fi

	# Enable Fast Transition
	change_fast_transition "0" "1"
	if [ "$(is_5ghz_capable)" = "1" ]
	then
		change_fast_transition "1" "1"
	fi

	enable_mesh_routing "$_mesh_mode"
fi

uci commit wireless

exit 0
