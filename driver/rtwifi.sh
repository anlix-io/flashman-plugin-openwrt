#!/bin/sh

get_radio_phy() {
	[ "$1" == "0" ] && echo "ra0" || echo "rai0"
}

get_phy_type() {
	#1: 2.4 2: 5GHz
	[ "$1" == "ra0" ] && echo "1" || echo "2"
}

# Get all ifnames from interfaces
get_ifnames() {
	# $1: Which interface:
		# 0: 2.4G
		# 1: 5G

	# Get all interfaces
	local _interfaces="$(ls /sys/devices/virtual/net)"

	# Only show interfaces with apcli or ra
	[ "$1" == "0" ] && echo "$_interfaces | $(grep -E "apcli"$1"|ra"$1"")" ||
	echo "$_interfaces | $(grep -E "apclii"$1"|rai"$1"")"
}

# Get only the root interface
get_root_ifname() {
	# $1: Which interface:
		# 0: 2.4G
		# 1: 5G

	# Show interfaces ra0 or rai0
	echo "$(get_ifnames "$1" | grep -E "ra|0")"
}

# Get the chosen virtual AP ifname
get_virtual_ap_ifname() {
	# $1: Which interface:
		# 0: 2.4G
		# 1: 5G
	# $2: Which virtual AP

	# Return the ifname with ra and the number
	echo "$(get_ifnames "$1" | grep -E "ra|"$2"")"
}

# Get the station ifname
get_station_ifname() {
	# $1: Which interface:
		# 0: 2.4G
		# 1: 5G

	# Return interface with apcli
	echo "$(get_ifnames "$1" | grep -E "apcli|0")"
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

