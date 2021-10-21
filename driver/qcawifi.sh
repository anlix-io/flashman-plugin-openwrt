#!/bin/sh

# It actually returns the logical device from the kernel, created with qsdk's wlanconfig tool
get_radio_phy() {
	[ "$1" == "0" ] && echo "ath0" || echo "ath1"
}

# Same thing from above, it expects the logical device
get_phy_type() {
	#1: 2.4 2: 5GHz
	[ "$1" == "ath0" ] && echo "1" || echo "2"
}

get_24ghz_phy() {
	local netname
	for i in /sys/class/net/* 
	do 
		iface=`basename $i` 
		[ "$iface" == "radio0" ] && echo $iface
	done
}

get_5ghz_phy() {
	local netname
	for i in /sys/class/net/* 
	do 
		iface=`basename $i` 
		[ "$iface" == "radio1" ] && echo $iface
	done
}

is_5ghz_vht() {
	local _5iface=$(get_5ghz_phy)
	[ "$_5iface" ] && echo "1"
}

#get_wifi_htmode() {
#
#}
#convert_txpower() {
#
#}
#get_txpower() {
#
#}

