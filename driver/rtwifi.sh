#!/bin/sh

get_radio_phy() {
	[ "$1" == "0" ] && echo "ra0" || echo "rai0"
}

get_phy_type() {
	#1: 2.4 2: 5GHz
	[ "$1" == "ra0" ] && echo "1" || echo "2"
}

get_24ghz_phy() {
	local netname
	for i in /sys/class/net/* 
	do 
		iface=`basename $i` 
		[ "$iface" == "ra0" ] && echo $iface
	done
}

get_5ghz_phy() {
	local netname
	for i in /sys/class/net/* 
	do 
		iface=`basename $i` 
		[ "$iface" == "rai0" ] && echo $iface
	done
}

is_5ghz_vht() {
	local _5iface=$(get_5ghz_phy)
	[ "$_5iface" ] && echo "1"
}

get_wifi_htmode() {
	echo "20"
}

convert_txpower() {
	local _freq="$1"
	local _channel="$2"
	local _txprct="$3"
	echo "$_txprct"
}

get_txpower() {
	local _iface="$1"
	local _txpower="$(uci -q get wireless.radio$_iface.txpower)"
	echo "$_txpower"
}

