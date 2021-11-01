#!/bin/sh
# WARNING! This file may be replaced depending on the selected target!
[ -e /usr/share/functions/custom_device.sh ] && . /usr/share/functions/custom_device.sh
. /lib/functions.sh
. /lib/functions/leds.sh
. /usr/share/functions/custom_wireless_driver.sh

is_5ghz_capable() {
	[ "$(get_5ghz_phy)" ] && echo "1" || echo "0"
}

get_wifi_channel(){
	local _phy=$(get_root_ifname $1)
	iwinfo $_phy info | awk '/Channel/ { print $4; exit }'
}

get_wifi_device_stats() {
	local _dev_mac="$1"
	local _dev_info
	local _wifi_itf
	local _ap_freq
	local _res
	local _base_noise="-92"

	for _ap_freq in "2.4" "5.0"
	do 
		if [ "$_ap_freq" == "2.4" ]
		then
			_wifi_itf="$(get_root_ifname 0)"
		else
			_wifi_itf="$(get_root_ifname 1)"
		fi

		_dev_info="$(iwinfo $_wifi_itf a 2> /dev/null)"
		_res=$(echo "$_dev_info" | awk -v MAC=$_dev_mac -v FREQ=$_ap_freq -e '
			BEGIN {
			  A=0;
			  F=0;
			} 

			/ago/ {
			  if (tolower($1) == tolower(MAC)) {
			    A=1;
			    F=1;
			    M=$1
			    S=$2
			    N=$5
			    I=$9
			  } else {
			    A=0;
			  }
			} 

			/TX/ {
			  if(A == 1) {
			    TXBITRATE=$2
			    TXPKT=$7
			  }
			}

			END {
			  if(FREQ == 5.0) 
			    FTYPE="AC"
			  else
			    FTYPE="N"

			  if(F == 1)
			    print TXBITRATE, "0.0", S, S-N, FREQ, FTYPE, "0.0", "0.0", TXPKT, "0.0", "1.0" 
			  else
			    print "0.0 0.0 0.0 0.0 0 Z 0 0 0 0 0"
			}
		')

		[ "${_res::3}" != "0.0" ] && break  
	done
	echo "$_res"
}

is_device_wireless() {
	local _dev_mac="$1"
	local _dev_info
	local _wifi_itf

	for _ap_freq in "2.4" "5.0"
	do 
		if [ "$_ap_freq" == "2.4" ]
		then
			_wifi_itf="$(get_root_ifname 0)"
		else
			_wifi_itf="$(get_root_ifname 1)"
		fi

		_dev_info="$(iwinfo $_wifi_itf a 2> /dev/null | grep -i $_dev_mac)"

		[ "$_dev_info" ] && return 0  
	done
	return 1
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

get_wan_statistics() {
	local _param=$1

	if [ "$(lsmod | grep hwnat)" ]
	then
		# MT7620 routers read data from swconfig, as hwnat mascarede the wan bytes
		if [ "$(type -t custom_switch_ports)" ]; then
			local _switch="$(custom_switch_ports 1)"
			local _wan_port="$(custom_switch_ports 2)"
		else
			local _switch="$(switch_ports 1)"
			local _wan_port="$(switch_ports 2)"
		fi
		A=$(swconfig dev $_switch port $_wan_port get mib 2>/dev/null)
		if [ "$A" ]
		then
			case "$1" in
				"TX") echo "$(echo "$A" | awk '/ifOutOctets/ { print $3 }')" ;;
				"RX") echo "$(echo "$A" | awk '/ifInOctets/ { print $3 }')" ;;
			esac
		else
			echo "0"
		fi
	else
		local _wan=$(get_wan_device)
		if [ -f /sys/class/net/$_wan/statistics/tx_bytes ]
		then
			case "$1" in
				"TX") echo "$(cat /sys/class/net/$_wan/statistics/rx_bytes)" ;;
				"RX") echo "$(cat /sys/class/net/$_wan/statistics/tx_bytes)" ;;
			esac
		else
			echo "0"
		fi
	fi
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
