#!/bin/sh

get_radio_phy() {
	[ "$1" == "0" ] && echo "ra0" || echo "rai0"
}

get_phy_type() {
	#1: 2.4 2: 5GHz
	[ "$1" == "ra0" ] && echo "1" || echo "2"
}

# Get only the root interface
get_root_ifname() {
	# $1: Which interface:
		# 0: 2.4G
		# 1: 5G

	# Show interfaces ra0 or rai0
	[ "$1" == "0" ] && echo "ra0" || echo "rai0"
}

# Get the station ifname
get_station_ifname() {
	# $1: Which interface:
		# 0: 2.4G
		# 1: 5G

	# Only one station interface for each radio
	[ "$1" == "0" ] && echo "apcli0" || echo "apclii0"
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

#mesh uses the first virtual ap
get_mesh_ap_bssid() {
	# $1: 2.4G or 5G
		# 0: 2.4G
		# 1: 5G
	if [ "$1" == "0" ]
	then
		cat /sys/class/net/ra1/address
	else
		[ -f /sys/class/net/rai1/address ] && cat /sys/class/net/rai1/address
	fi
}

get_mesh_ap_ifname() {
	[ "$1" == "0" ] && echo "ra1" || echo "rai1"
}

#get the others virtusl aps
get_virtual_ap_ifname() {
	# $1: Which interface:
		# 0: 2.4G
		# 1: 5G
	# $2: Which virtual AP
	local _idx=$2
	# Return the ifname with ra and the number
	[ "$1" == "0" ] && echo "ra$((_idx+1))" || echo "rai$((_idx+1))"
}
