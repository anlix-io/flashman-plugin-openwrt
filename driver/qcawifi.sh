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

# Since it will be the default_radioX ifname, it still uses the logical device
get_root_ifname() {
	
	[ "$1" == "0" ] && echo "ath0" || echo "ath1"
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

get_wifi_htmode(){
	iwpriv ath$1 get_mode | sed -r -e 's/.*HT//g' -e 's/([0-9]+).*/\1/'
}

convert_txpower() {
	local _freq="$1"
	local _channel="$2"
	local _target_tx_percent="$3"
	local _maxpwr
	
	if [ $_freq = "24" ] ; then 
		_maxpwr=$(custom_wifi_24_txpower)
	elif [ $_freq = "50" ] ; then 
		_maxpwr=$(custom_wifi_50_txpower)	
	fi
	echo $(( (_maxpwr*_target_tx_percent)/100 ))
}

get_txpower() {
	local _idx="$1"
	local _txpower="$(uci -q get wireless.radio$_idx.txpower)"
	local _maxpwr

	if   [ $_idx = "0" ]; then _maxpwr=$(custom_wifi_24_txpower)
	elif [ $_idx = "1" ]; then _maxpwr=$(custom_wifi_50_txpower)	
	fi

	local _txprct="$(( (_txpower * 100) / _maxpwr ))"
	if   [ $_txprct -ge 100 ]; then echo "100"
	elif [ $_txprct -ge 75 ]; then echo "75"
	elif [ $_txprct -ge 50 ]; then echo "50"
	else echo "25"
	fi
}

