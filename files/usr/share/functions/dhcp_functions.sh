#!/bin/sh

. /usr/share/libubox/jshn.sh
. /usr/share/functions/device_functions.sh

get_device_mac_from_ip() {
	local _ip=$1
	local _arp_mac=$(cat /proc/net/arp | grep "$_ip" | awk '{ print $4 }')
	echo "$_arp_mac"
}

get_device_conn_type() {
	local _mac=$1
	local _online=$2
	local _retstatus

	is_device_wireless "$_mac"
	_retstatus=$?
	if [ $_retstatus -eq 0 ]
	then
		# Wireless
		echo "1"
	else
		if [ "$_online" == "1" ]
		then
			# Wired
			echo "0"
			return
		fi
		local _state=$(ip neigh | grep "$_mac" | awk '{print $NF}')
		for i in $_state
		do
			if [ "$i" == "REACHABLE" ]
			then
				# Wired
				echo "0"
				return
			fi
		done
		# Not connected
		echo "2"
	fi
}

# IPV6 dhcp are uid not mac
# Send a probe to search for mac in ip neigh
get_ipv6_dhcp() {
	json_init
	local DHCP=$(ubus -v call dhcp ipv6leases)
	json_load "$DHCP"
	json_select "device"
	if json_get_type type "br-lan" && [ "$type" = object ]; then
		json_select "br-lan"
		if json_get_type type "leases" && [ "$type" = array ]; then
			json_select "leases"
			local Index="1"
			while json_get_type type $Index && [ "$type" = object ]; do
				json_select "$((Index++))"
				json_get_var duid "duid"
				json_select "ipv6-addr"
				local Index_Addr="1"
				while json_get_type type $Index_Addr && [ "$type" = object ]; do
					json_select "$((Index_Addr++))"
					json_get_var addrv6 "address"

					# We need to "wake up" the ip to get the mac from ip neigh
					ping6 -I br-lan -q -c 1 -w 1 "$addrv6" > /dev/null 2>&1
					local _macaddr=$(ip -6 neigh | grep "$addrv6" | awk '{ if($4 == "lladdr") print $5 }')
					if [ ! -z $_macaddr ]; then
						echo $duid $_macaddr $addrv6
					fi

					json_select ".."
				done
				json_select ".."
				json_select ".."
			done
		fi
	fi
}

check_dev_online_status() {
	local _mac="$1"
	local _ipv4_neigh="$2"
	local _ipv6_neigh="$3"
	local _ipv4="$(echo "$_ipv4_neigh" | grep "$_mac" | awk '{ print $2 }')"
	local _ipv6="$(echo "$_ipv6_neigh" | grep "$_mac" | awk '{ print $2 }')"
	local _res

	# check online in ipv4
	_res="$(ping -q -c 1 -w 1 "$i" 2>/dev/null)"
	if [ $? -eq 0 ]
	then
		mv "/tmp/onlinedevscheck/$_mac.wait" "/tmp/onlinedevscheck/$_mac.on"
		echo "$(echo $_res|sed -ne 's/.* = \([0-9\.]*\)*.*/\1/p')" > "/tmp/onlinedevscheck/$_mac.on"
		return
	fi

	for i in $_ipv6
	do
		_res=$(ping6 -I br-lan -q -c 1 -w 1 "$i" 2>/dev/null)
		if [ $? -eq 0 ]
		then
			mv "/tmp/onlinedevscheck/$_mac.wait" "/tmp/onlinedevscheck/$_mac.on"
			echo "$(echo $_res|sed -ne 's/.* = \([0-9\.]*\)*.*/\1/p')" > "/tmp/onlinedevscheck/$_mac.on"
			return
		fi
	done

	# if cant connect, check arp table
	local _count=0
	local _state=$(ip neigh | grep "$_mac" | awk '{print $NF}')
	local _ctrl=$(echo "$_state" | grep "DELAY")
	while [ ! -z "$_ctrl" ] || [ $_count -eq 2 ]
	do
		sleep 2
		_state=$(ip neigh | grep "$_mac" | awk '{print $NF}')
		_ctrl=$(echo "$_state" | grep "DELAY")
		_count=$((_count+1))
	done

	for s in $_state
	do
		if [ "$s" == "REACHABLE" ]
		then
			mv "/tmp/onlinedevscheck/$_mac.wait" "/tmp/onlinedevscheck/$_mac.on"
			return
		fi
	done

	mv "/tmp/onlinedevscheck/$_mac.wait" "/tmp/onlinedevscheck/$_mac.off"
	return
}

get_online_devices() {
	local _dhcp_ipv6=""
	[ "$(get_ipv6_enabled)" != "0" ] && _dhcp_ipv6=$(get_ipv6_dhcp)
	local _ipv4_neigh="$(ip -4 neigh | grep lladdr | awk '{ if($3 == "br-lan") print $5, $1}')"
	local _ipv6_neigh=""
	[ "$(get_ipv6_enabled)" != "0" ] &&_ipv6_neigh="$(ip -6 neigh | grep lladdr | awk '{ if($3 == "br-lan") print $5, $1}')"
	local _macs_v4="$(echo "$_ipv4_neigh" | awk '{ print $1 }')"
	local _macs_v6="$(echo "$_ipv6_neigh" | awk '{ print $1 }')"
	local _macs="$(printf %s\\n%s "$_macs_v4" "$_macs_v6" | sort | uniq)"
	local _local_itf_macs="$(ifconfig | grep HWaddr | awk '{ print tolower($NF) }' | sort | uniq)"
	local _mesh_routers="$(ubus call anlix_sapo get_routers_mac | jsonfilter -e '@.routers[@].mac' | awk '{ print tolower($NF) }' | sort | uniq)"

	# Remove MACs related to the router itself and mesh neighbors
	local _local_mac_duplicates="$(printf %s\\n%s\\n%s "$_macs" "$_local_itf_macs" "$_mesh_routers" | sort | uniq -d)"
	for _mac in $_local_mac_duplicates
	do
		_macs="$(printf %s\\n%s "$_macs" | sed "/$_mac/d")"
	done

	# Create control dir with device status
	[ -d /tmp/onlinedevscheck ] && rm -rf /tmp/onlinedevscheck
	mkdir /tmp/onlinedevscheck
	for _mac in $_macs
	do
		touch "/tmp/onlinedevscheck/$_mac.wait"
	done
	# Dispatch pings and arp checks for each device
	for _mac in $_macs
	do
		(check_dev_online_status "$_mac" "$_ipv4_neigh" "$_ipv6_neigh" & )
	done
	# Wait pings and arp checks completion
	local _wait_complete=1
	while [ $_wait_complete -eq 1 ]
	do
		ls /tmp/onlinedevscheck | grep -q "wait"
		if [ $? -eq 0 ]
		then
			sleep 1
		else
			break
		fi
	done
	# Filter only online devs
	_macs=$(ls /tmp/onlinedevscheck | grep ".on" | awk -F. '{print $1}')
	# Create JSON with online devices
	json_add_object "Devices"
	for _mac in $_macs
	do
		local _ipv4="$(echo "$_ipv4_neigh" | grep "$_mac" | awk '{ print $2 }')"

		local _ipv6=""
		[ "$(get_ipv6_enabled)" != "0" ] && _ipv6="$(echo "$_ipv6_neigh" | grep "$_mac" | awk '{ print $2 }')"

		local _hostname=""
		local _conn_type="$(get_device_conn_type $_mac $_online)"
		local _conn_speed=""
		local _dev_signal=""
		local _dev_snr=""
		local _dev_freq=""
		local _dev_mode=""
		local _dev_ping=""
		local _dev_rx=""
		local _dev_tx=""
		local _dev_conntime=""
		local _dev_signature=""
		local _dhcp_signature=""
		local _dhcp_vendor_class=""

		if [ -f /tmp/dhcp.leases ]
		then
			_hostname="$(cat /tmp/dhcp.leases | grep $_mac | awk '{ if ($4=="*") print "!"; else print $4 }')"
		fi

		if [ "$_conn_type" == "0" ]
		then
			# Get speed from LAN ports
			_conn_speed=$(get_lan_dev_negotiated_speed $_mac)
		elif [ "$_conn_type" == "1" ]
		then
			local _wifi_stats="$(get_wifi_device_stats $_mac)"
			# Get wireless bitrate
			_conn_speed=$(echo $_wifi_stats | awk '{print $1}')
			_dev_signal=$(echo $_wifi_stats | awk '{print $3}')
			_dev_snr=$(echo $_wifi_stats | awk '{print $4}')
			_dev_freq=$(echo $_wifi_stats | awk '{print $5}')
			_dev_mode=$(echo $_wifi_stats | awk '{print $6}')
			_dev_tx=$(echo $_wifi_stats | awk '{print $7}')
			_dev_rx=$(echo $_wifi_stats | awk '{print $8}')
			_dev_conntime=$(echo $_wifi_stats | awk '{print $11}')

			if [ "$(type -t get_wifi_device_signature)" ]
			then
				_dev_signature="$(get_wifi_device_signature $_mac)"
			fi
		fi
		_dev_ping=$([ -s "/tmp/onlinedevscheck/$_mac.on" ] && cat "/tmp/onlinedevscheck/$_mac.on")

		if [ -e "/tmp/dhcpinfo/$_mac" ]
		then
			_dhcp_signature="$(cat /tmp/dhcpinfo/"$_mac" | awk '{print $1}')"
			_dhcp_vendor_class="$(cat /tmp/dhcpinfo/"$_mac" | awk '{print $2}')"
		fi

		json_add_object "$_mac"
		json_add_string "ip" "$_ipv4"
		json_add_array "ipv6"
		for _i6 in $_ipv6
		do
			json_add_string "" "$_i6"
		done
		json_close_array
		json_add_array "dhcpv6"
		if [ "$(get_ipv6_enabled)" != "0" ]
		then
			for _i6 in $(echo  "$_dhcp_ipv6" | grep $_mac | awk '{print $3}')
			do
				json_add_string "" "$_i6"
			done
		fi
		json_close_array
		json_add_string "hostname" "$_hostname"
		json_add_string "conn_type" "$_conn_type"
		json_add_string "conn_speed" "$_conn_speed"
		json_add_string "wifi_signal" "$_dev_signal"
		json_add_string "wifi_snr" "$_dev_snr"
		json_add_string "wifi_freq" "$_dev_freq"
		json_add_string "wifi_mode" "$_dev_mode"
		json_add_string "ping" "$_dev_ping"
		json_add_string "tx_bytes" "$_dev_tx"
		json_add_string "rx_bytes" "$_dev_rx"
		json_add_string "conn_time" "$_dev_conntime"
		json_add_string "wifi_signature" "$_dev_signature"
		json_add_string "dhcp_signature" "$_dhcp_signature"
		json_add_string "dhcp_vendor_class" "$_dhcp_vendor_class"
		json_close_object
	done
	json_close_object
}

get_online_mesh_routers() {
	local _routers=""
	local _stations=""
	local _r
	if [ -e /sys/class/net/mesh0 ]
	then
		_routers="$(iw dev mesh0 mpath dump | awk '/mesh0/{print $1}')"
		_stations="$(iw dev mesh0 station dump)"
	fi
	if [ -e /sys/class/net/mesh1 ]
	then
		if [ "$_routers" ]
		then
			_routers="$_routers $(iw dev mesh1 mpath dump | awk '/mesh1/{print $1}')"
		else
			_routers="$(iw dev mesh1 mpath dump | awk '/mesh1/{print $1}')"
		fi
		if [ "$_stations" ]
		then
			_stations="$_stations $(iw dev mesh1 station dump)"
		else
			_stations="$(iw dev mesh1 station dump)"
		fi
	fi

	local _mac
	json_add_object "mesh_routers"
	while [ "$(echo "$_stations"|xargs)" ]
	do
		_r=${_stations##*Station}
		_stations=${_stations%Station *}
		_mac="$(echo ${_r%% (*}|xargs)"
		case "$_routers" in *"$_mac"*)
			json_add_object "$_mac"
			json_add_string "signal" "$(echo "$_r"|awk '/signal:/{print $2}')"
			json_add_string "conn_time" "$(echo "$_r"|awk '/connected time:/{print $3}')"
			json_add_string "rx_bytes" "$(echo "$_r"|awk '/rx bytes:/{print $3}')"
			json_add_string "tx_bytes" "$(echo "$_r"|awk '/tx bytes:/{print $3}')"
			json_add_string "rx_bit" "$(echo "$_r"|awk '/rx bitrate:/{print $3}')"
			json_add_string "tx_bit" "$(echo "$_r"|awk '/tx bitrate:/{print $3}')"
			json_add_string "iface" "$(echo "$_r"| awk '/\(on /{print substr($3, 1, 5)}')"
			json_close_object
			;;
		esac
	done

	json_close_object
}

send_online_devices() {
	local _res

	json_init
	get_online_devices
	[ "$(get_mesh_mode)" -gt 1 ] && get_online_mesh_routers

	_res=$(json_dump | curl -s --tlsv1.2 --connect-timeout 5 \
				--retry 1 -H "Content-Type: application/json" \
				-H "X-ANLIX-ID: $(get_mac)" \
				-H "X-ANLIX-SEC: $FLM_CLIENT_SECRET" \
				--data @- "https://$FLM_SVADDR/deviceinfo/receive/devices")
	json_cleanup
	json_load "$_res"
	json_get_var _processed processed
	json_close_object

	return $_processed
}

get_active_device_leases() {
	local _devarraystr="{\"data\":["
	local _devlist
	[ -f /tmp/dhcp.leases ] && _devlist=$(cat /tmp/dhcp.leases | awk '{ print $2 }')
	local _hostname
	local _dev
	for _dev in $_devlist
	do
		_hostname=""
		_hostname=$(cat /tmp/dhcp.leases | grep "$_dev" | awk '{ print $4 }')
		_devarraystr="$_devarraystr\
{\"{#MAC}\":\"$_dev\", \"{#DEVHOSTNAME}\":\"$_hostname\"},"
	done
	_devarraystr=$_devarraystr"]}"
	echo $_devarraystr | sed 's/\(.*\),/\1/'
}
