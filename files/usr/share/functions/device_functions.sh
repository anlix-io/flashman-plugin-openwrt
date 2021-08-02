#!/bin/sh
# WARNING! This file may be replaced depending on the selected target!
[ -e /usr/share/functions/custom_device.sh ] && . /usr/share/functions/custom_device.sh
. /lib/functions.sh
. /lib/functions/leds.sh

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

is_5ghz_capable() {
	[ "$(get_5ghz_phy)" ] && echo "1" || echo "0"
}

is_mesh_routing_capable() {
	local _ret=0
	local _ret5=0
	local _24iface=$(get_24ghz_phy)
	local _5iface=$(get_5ghz_phy)
	[ "$_24iface" ] && [ "$(iw phy $_24iface info|grep "mesh point")" ] && _ret=1
	[ "$_5iface" ] && [ "$(iw phy $_5iface info|grep "mesh point")" ] && _ret5=1
	if [ "$_ret5" -eq "1" ] 
	then
		[ "$_ret" -eq "1" ] && echo "3" || echo "2"
	else
		echo "$_ret"
	fi
}

is_mesh_capable() {
	[ -f /usr/sbin/wpad ] && [ "$(is_mesh_routing_capable)" != "0" ] && echo "1"
}

get_wifi_device_stats() {
	local _dev_mac="$1"
	local _dev_info
	local _wifi_stats=""
	local _retstatus
	local _cmd_res
	local _wifi_itf="wlan0"
	local _ap_freq="2.4"
	local _base_noise="-92"

	_cmd_res=$(command -v iw)
	_retstatus=$?

	if [ $_retstatus -eq 0 ]
	then
		_dev_info="$(iw dev $_wifi_itf station get $_dev_mac 2> /dev/null)"
		_retstatus=$?

		if [ $_retstatus -ne 0 ]
		then
			_wifi_itf="wlan1"
			_ap_freq="5.0"
			_dev_info="$(iw dev $_wifi_itf station get $_dev_mac 2> /dev/null)"
			_retstatus=$?
		fi

		if [ $_retstatus -eq 0 ]
		then
			local _dev_txbitrate="$(echo "$_dev_info" | grep 'tx bitrate:' | awk '{print $3}')"
			local _dev_rxbitrate="$(echo "$_dev_info" | grep 'rx bitrate:' | awk '{print $3}')"
			local _dev_mcs="$(echo "$_dev_info" | grep 'tx bitrate:' | awk '{print $5}')"
			local _dev_signal="$(echo "$_dev_info" | grep -m1 'signal:' | awk '{print $2}' | awk -F. '{print $1}')"
			local _ap_noise="$(iwinfo $_wifi_itf info | grep 'Noise:' | awk '{print $5}' | awk -F. '{print $1}')"
			local _dev_txbytes="$(echo "$_dev_info" | grep 'tx bytes:' | awk '{print $3}')"
			local _dev_rxbytes="$(echo "$_dev_info" | grep 'rx bytes:' | awk '{print $3}')"
			local _dev_txpackets="$(echo "$_dev_info" | grep 'tx packets:' | awk '{print $3}')"
			local _dev_rxpackets="$(echo "$_dev_info" | grep 'rx packets:' | awk '{print $3}')"
			local _dev_conntime="$(echo "$_dev_info" | grep 'connected time:' | awk '{print $3}')"

			_ap_noise=$([ "$_ap_noise" == "unknown" ] && echo "$_base_noise" || echo "$_ap_noise")
			if [ "$_ap_noise" -lt "$_base_noise" ]
			then
				_ap_noise="$_base_noise"
			fi

			# Calculate SNR
			local _dev_snr="$(($_dev_signal - $_ap_noise))"

			_wifi_stats="$_dev_txbitrate $_dev_rxbitrate $_dev_signal"
			_wifi_stats="$_wifi_stats $_dev_snr $_ap_freq"

			[ "$_dev_mcs" == "VHT-MCS" ] && _wifi_stats="$_wifi_stats AC" || _wifi_stats="$_wifi_stats N"
			# Traffic data
			_wifi_stats="$_wifi_stats $_dev_txbytes $_dev_rxbytes"
			_wifi_stats="$_wifi_stats $_dev_txpackets $_dev_rxpackets"
			_wifi_stats="$_wifi_stats $_dev_conntime"
			echo "$_wifi_stats"
		else
			echo "0.0 0.0 0.0 0.0 0 Z 0 0 0 0 0"
		fi
	else
		echo "0.0 0.0 0.0 0.0 0 Z 0 0 0 0 0"
	fi
}

is_device_wireless() {
	local _dev_mac="$1"
	local _dev_info
	local _retstatus
	local _cmd_res
	local _wifi_itf="wlan0"

	_cmd_res=$(command -v iw)
	_retstatus=$?

	if [ $_retstatus -eq 0 ]
	then
		_dev_info="$(iw dev $_wifi_itf station get $_dev_mac 2> /dev/null)"
		_retstatus=$?

		if [ $_retstatus -ne 0 ]
		then
			_wifi_itf="wlan1"
			_dev_info="$(iw dev $_wifi_itf station get $_dev_mac 2> /dev/null)"
			_retstatus=$?
		fi

		[ $_retstatus -eq 0 ] && return 0 || return 1
	else
		return 1
	fi
}

leds_off() {
	for trigger_path in $(ls -d /sys/class/leds/*)
	do
		led_off "$(basename "$trigger_path")"
	done
}

# Default switch configuration
switch_ports() {
	case $1 in
		1) echo "switch0" ;; # switch name
		2) echo "0" ;; # wan port
		3) echo "1 2 3 4" ;; # lan ports
		4) echo "6" ;; # cpu port
		5) echo "4" ;; # number of lan ports
	esac
}

reset_leds() {
	leds_off
	/etc/init.d/led restart > /dev/null
	led_on "$(get_dt_led running)"
}

blink_leds() {
	if [ $1 -eq 0 ]
	then
		local led_blink="$([ "$(type -t get_custom_leds_blink)" ] &&  get_custom_leds_blink || ls -d /sys/class/leds/*green*)"
		leds_off
		for trigger_path in $led_blink; do
			led_timer "$(basename "$trigger_path")" 500 500
		done
	fi
}

get_mac() {
	if [ "$(type -t get_custom_mac)" ]
	then
		get_custom_mac
	else
		local _mac_address_tag=""
		local _p1

		_p1=$(awk '{print toupper($1)}' /sys/class/net/eth0/address)
		[ ! -z "$_p1" ] && _mac_address_tag=$_p1

		echo "$_mac_address_tag"
	fi
}

get_vlan_device() {
	parse_get_switch() { 
		config_get device $2 device 
		config_get vlan $2 vlan
		[ $vlan -eq $1 ] && echo "${device}" 
	}
	config_load network
	swt=$(config_foreach "parse_get_switch $1" switch_vlan)
	echo "$swt"
}

get_vlan_ports() {
	local _switch="$(get_vlan_device $1)"
	local _port=$(swconfig dev $_switch vlan $1 get ports)
	echo "$(for i in $_port; do [ "${i:1}" != "t" ] && echo $i; done)"
}

get_wan_device() {
	ubus call network.interface.wan status|jsonfilter -e "@.device"
}

get_switch_device() {
	local _switch
	for i in $(swconfig list)
	do 
		[ -z "${i%switch*}" ] && _switch="$i" 
	done
	echo "$_switch"
}

is_device_vlan() {
	local _iface=$1
	[ "${_iface:4:1}" == "." ] && echo "1"
}

get_device_vlan() {
	local _iface=$1
	echo "${_iface:5:1}"
}

get_wan_negotiated_speed() {
	local _wan=$(get_wan_device)
	if [ "$(type -t custom_switch_ports)" ] || [ "$(is_device_vlan $_wan)" ]
	then
		local _switch
		local _port
		if [ "$(type -t custom_switch_ports)" ]
		then
			_switch="$(custom_switch_ports 1)"
			_port="$(custom_switch_ports 2)"
		else
			local _vport=$(get_device_vlan $_wan)
			_switch="$(get_vlan_device $_vport)"
			_port="$(get_vlan_ports $_vport)"
		fi
		echo "$(swconfig dev $_switch port $_port get link|sed -ne 's/.*speed:\([0-9]*\)*.*/\1/p')"
	else
		cat /sys/class/net/$_wan/speed
	fi
}

get_wan_negotiated_duplex() {
	local _wan=$(get_wan_device)
	if [ "$(type -t custom_switch_ports)" ] || [ "$(is_device_vlan $_wan)" ]
	then
		local _switch
		local _port
		if [ "$(type -t custom_switch_ports)" ]
		then
			_switch="$(custom_switch_ports 1)"
			_port="$(custom_switch_ports 2)"
		else
			local _vport=$(get_device_vlan $_wan)
			_switch="$(get_vlan_device $_vport)"
			_port="$(get_vlan_ports $_vport)"
		fi
		echo "$(swconfig dev $_switch port $_port get link|sed -ne 's/.* \([a-z]*\)-duplex*.*/\1/p')"
	else
		cat /sys/class/net/$_wan/duplex
	fi
}

get_lan_dev_negotiated_speed() {
	local _speed="0"
	local _switch="$(get_vlan_device 1)"
	[ -z "$_switch" ] && _switch="$(get_switch_device)"
	[ -z "$_switch" ] && (
		log "get_lan_dev_speed" "Cant get lan switch device!"
		return
	)

	local _switch_ports
	if [ "$(type -t custom_switch_ports)" ]
	then
		_switch_ports="$(custom_switch_ports 3)"
	else
		_switch_ports="$(get_vlan_ports 1)"
	fi
	[ -z "$_switch_ports" ] && (
		log "get_lan_dev_speed" "Cant get lan switch ports!"
		return
	)

	for _port in $_switch_ports; do
		local _speed_tmp="$(swconfig dev $_switch port $_port get link|sed -ne 's/.*speed:\([0-9]*\)*.*/\1/p')"
		if [ "$_speed_tmp" != "" ]
		then
			if [ "$_speed" != "0" ]
			then
				[ "$_speed" != "$_speed_tmp" ] && _speed="0"
			else
				# First assignment
				_speed="$_speed_tmp"
			fi
		fi
	done

	echo "$_speed"
}

get_wifi_device_signature() {
	local _dev_mac="$1"
	local _q=""
	_q="$(ubus -S call hostapd.wlan0 get_clients | jsonfilter -e '@.clients["'"$_dev_mac"'"].signature')"
	[ -z "$_q" ] && [ "$(is_5ghz_capable)" -eq "1" ] && _q="$(ubus -S call hostapd.wlan1 get_clients | jsonfilter -e '@.clients["'"$_dev_mac"'"].signature')"
	echo "$_q"
}

needs_reboot_change_mode() {
	reboot
}
