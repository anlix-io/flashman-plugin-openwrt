#!/bin/sh

get_radio_phy() {
	echo "$(ls /sys/devices/$(uci get wireless.radio$1.path)/ieee80211)"
}

get_phy_type() {
	#1: 2.4 2: 5GHz
	echo "$(iw phy $1 channels|grep Band|tail -1|cut -c6)"
}

get_24ghz_phy() {
	for i in /sys/class/ieee80211/* 
	do 
		iface=`basename $i` 
		[ "$(get_phy_type $iface)" -eq "1" ] && echo $iface
	done
}

get_5ghz_phy() {
	for i in /sys/class/ieee80211/* 
	do 
		iface=`basename $i` 
		[ "$(get_phy_type $iface)" -eq "2" ] && echo $iface
	done
}

is_5ghz_vht() {
	local _5iface=$(get_5ghz_phy)
	[ "$_5iface" ] && [ "$(iw phy $_5iface info|grep "VHT")" ] && echo "1"
}

get_wifi_device_signature() {
	local _dev_mac="$1"
	local _q=""
	_q="$(ubus -S call hostapd.wlan0 get_clients | jsonfilter -e '@.clients["'"$_dev_mac"'"].signature')"
	[ -z "$_q" ] && [ "$(is_5ghz_capable)" -eq "1" ] && _q="$(ubus -S call hostapd.wlan1 get_clients | jsonfilter -e '@.clients["'"$_dev_mac"'"].signature')"
	echo "$_q"
}

get_wifi_htmode(){
	iw dev wlan$1 info 2>/dev/null|grep width|awk '{print $6}'
}

#need convert % to dbm
convert_txpower() {
	local _freq="$1"
	local _channel="$2"
	local _txprct="$3"
	local _maxpwr

	if [ "$_freq" = "24" ] 
	then
		_maxpwr=20
		[ "$(type -t custom_wifi_24_txpower)" ] && _maxpwr="$(custom_wifi_24_txpower)"
	else
		_maxpwr=30
		[ "$(type -t custom_wifi_50_txpower)" ] && _maxpwr="$(custom_wifi_50_txpower)"
	fi

	if [ "$_channel" = "auto" ] 
	then
		echo "$_maxpwr"
		return
	fi

	local _phy
	local _reload=0
	if [ "$_freq" = "24" ]
	then
		_phy=$(get_24ghz_phy)
		[ ! "$(type -t custom_wifi_24_txpower)" ] && _reload=1
	else
		_phy=$(get_5ghz_phy)
		[ ! "$(type -t custom_wifi_50_txpower)" ] && _reload=1
	fi
	[ $_reload = 1 ] && _maxpwr=$(iw $_phy info | awk '/\['$_channel'\]/{ print substr($5,2,2) }')

	echo $(( ((_maxpwr * _txprct)+50) / 100 ))
}

get_txpower() {
	local _iface="$1"
	local _txpower="$(uci -q get wireless.radio$_iface.txpower)"
	local _channel="$(uci -q get wireless.radio$_iface.channel)"

	if [ "$_channel" = "auto" ] 
	then
		echo "100" 
		return
	fi

	local _phy
	local _maxpwr="0"
	if [ "$_freq" = "0" ]
	then
		_phy=$(get_24ghz_phy)
		[ "$(type -t custom_wifi_24_txpower)" ] && _maxpwr="$(custom_wifi_24_txpower)"
	else
		_phy=$(get_5ghz_phy)
		[ "$(type -t custom_wifi_50_txpower)" ] && _maxpwr="$(custom_wifi_50_txpower)"
	fi
	[ "$_maxpwr" = "0" ] && _maxpwr=$(iw $_phy info | awk '/\['$_channel'\]/{ print substr($5,2,2) }')

	local _txprct="$(( (_txpower * 100) / _maxpwr ))"
	if   [ $_txprct -ge 100 ]; then echo "100"
	elif [ $_txprct -ge 75 ]; then echo "75"
	elif [ $_txprct -ge 50 ]; then echo "50"
	else echo "25"
	fi
}

