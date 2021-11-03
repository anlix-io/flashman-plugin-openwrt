#!/bin/sh

. /usr/share/libubox/jshn.sh
. /usr/share/functions/common_functions.sh

get_device_mac_from_ip() {
	local _ip=$1
	local _arp_mac=$(cat /proc/net/arp | grep "$_ip" | awk '{ print $4 }')
	echo "$_arp_mac"
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

get_online_devices() {
	local _MACS6 _MACS4 _MACSW
	local _NUMACS4=0
	local _NUMACS6=0
	local _NUMACSW=0
	local _mesh_slave="$(is_mesh_slave)"
	local _mesh_routers

	local _local_itf_macs="$(ip link | awk '/link\/ether/{a[$2]++} END{for(b in a)print b}')"

	#Information that only master have
	if [ "$_mesh_slave" = "0" ]
	then
		# Get all connected devices using arp (cable and wifi)
		# Get hostname from dhcp.lease
		# _router# = (ip RTT hostname)
		local _dhcp_info_ipv4=$([ -f /tmp/dhcp.leases ] && cat /tmp/dhcp.leases)
		eval "$(arp-scan -l -D -x -r1 2>/dev/null | awk -v dhcp="$_dhcp_info_ipv4" '
			BEGIN{
				n1=split(dhcp, arr1, "\n");
				for (i=1;i<=n1;i++) {
					n2=split(arr1[i], ar);
					A[ar[2]]=ar[3];
					if (ar[4]=="*")
						C[ar[2]]="!"
					else
						C[ar[2]]=ar[4]
				}
			}
			{
				A[$2]=$1;
				split($4, ar, "=");
				B[$2]=ar[2];
			}
			END{
				count=0
				MA=""
				for (b in A) {
					printf "_router%d=\"", count;
					printf "\\\"%s\\\" ", A[b];
					printf "\\\"%s\\\" ", B[b];
					printf "\\\"%s\\\" ", C[b];
					print "\";"
					MA=MA b ":" count " "
					count++;
				}
				printf "_MACS4=\"%s\";", MA
				printf "_NUMACS4=%d", count
			}')"

		#Get IPv6 dhcp information
		# _6router# = (ip6 ip6 ... )
		if [ "$(get_ipv6_enabled)" != "0" ]
		then
			eval "$(ip -6 neigh | awk -v dhcp="$(get_ipv6_dhcp)" '
				BEGIN{
					n1=split(dhcp, arr1, "\n");
					for (i=1;i<=n1;i++) {
						n2=split(arr1[i], ar);
						A[ar[2]]=A[ar[2]]" "ar[3];
					}
				}
				{
					if($3 == "br-lan" && $4 == "lladdr") {
						A[$5]=A[$5]" "$1
					}
				}
				END{
					count=0
					MA6=""
					for (b in A) {
						printf "_6router%d=\"", count;
						printf "%s ", A[b];
						print "\";"
						MA6=MA6 b ":" count " "
						count++;
					}
					printf "_MACS6=\"%s\";", MA6
					printf "_NUMACS6=%d", count
				}')"
		fi
	fi

	#Get connected wireless devices reported by wireless driver
	# _Wireless# = ( SIGNAL SNR IDLE FREQ MODE TXBITRATE TXPKT )
	local _dev_info="$(iwinfo $(get_root_ifname 0) a 2> /dev/null)"
	[ "$(is_5ghz_capable)" == "1" ] && _dev_info=$_dev_info$'\n'"5GHZ"$'\n'"$(iwinfo $(get_root_ifname 1) a 2> /dev/null)"
	eval "$(echo "$_dev_info" | awk  '
		BEGIN{f=2.4}

		/ago/ {
			M=tolower($1)
			SIGNAL[M]=$2
			SNR[M]=$5-$2
			IDLE[M]=$9
			FREQ[M]=f
			if(f == 5.0)
				MODE[M]="AC"
			else
				MODE[M]="N"
		}

		/TX/ {
			TXBITRATE[M]=$2
			TXPKT[M]=$7
		}

		/5GHZ/{
			f=5.0
		}

		END {
			count=0
			MW=""
			for (b in SIGNAL) {
				printf "_wireless%d=\"", count;
				printf "%s %s %s %s %s %s %s", SIGNAL[b], SNR[b], IDLE[b], FREQ[b], MODE[b], TXBITRATE[b], TXPKT[b];
				print "\";"
				MW=MW b ":" count " "
				count++;
			}
			printf "_MACSW=\"%s\";", MW
			printf "_NUMACSW=%d", count
		}
	')"

	get_index_array() {
		local _idxn
		case "$1" in
			*"$2"*)
				_idxn=${1##*"$2":}
				echo ${_idxn::1}
			;;
		esac
	}

	# Create JSON with online devices
	json_init
	json_add_object "Devices"
	local _processed_macs=""
	local _mac _i6 _dhcp_signature _dhcp_vendor_class

	# 1. Send all wireless devices
	for _mac in $_MACSW
	do
		local _idxf
		local _idx=${_mac##*:}
		local _rmac=${_mac%:*}
		json_add_object "$_rmac"

		_idxf=$(get_index_array "$_MACS4" "$_rmac")
		if [ $_idxf ]
		then
			local I0 I1 I2
			get_data 3 I $(eval echo \$_router$_idxf)
			json_add_string "ip" "$I0"
			json_add_string "ping" "$I1"
			json_add_string "hostname" "$I2"
		fi

		json_add_array "ipv6"
		_idxf=$(get_index_array "$_MACS6" "$_rmac")
		if [ $_idxf ]
		then
			for _i6 in $(eval echo \$_6router$_idxf)
			do
				json_add_string "" "$_i6"
			done
		fi
		json_close_array

		local R0 R1 R2 R3 R4 R5 R6
		get_data 7 R $(eval echo \$_wireless$_idx)

		_dhcp_signature=""
		_dhcp_vendor_class=""
		if [ -e "/tmp/dhcpinfo/$_rmac" ]
		then
			local D0 D1
			get_data 2 D $(cat /tmp/dhcpinfo/$_rmac)
			_dhcp_signature="$D0"
			_dhcp_vendor_class="$D1"
		fi

		if [ "$(type -t get_wifi_device_signature)" ]
		then
			_dev_signature="$(get_wifi_device_signature $_rmac)"
		fi

		json_add_string "conn_type" "1"
		json_add_string "conn_speed" "$R5"
		json_add_string "wifi_signal" "$R0"
		json_add_string "wifi_snr" "$R1"
		json_add_string "wifi_freq" "$R3"
		json_add_string "wifi_mode" "$R4"
		json_add_string "tx_bytes" ""
		json_add_string "rx_bytes" ""
		json_add_string "conn_time" ""
		json_add_string "wifi_signature" "$_dev_signature"
		json_add_string "dhcp_signature" "$_dhcp_signature"
		json_add_string "dhcp_vendor_class" "$_dhcp_vendor_class"
		json_close_object
		_processed_macs="$_processed_macs $_rmac"
	done

	# 2. Send cable ipv4 devs
	for _mac in $_MACS4
	do
		local _idxf
		local _idx=${_mac##*:}
		local _rmac=${_mac%:*}

		case "$_processed_macs" in
			*"$_rmac"*) continue;;
		esac

		json_add_object "$_rmac"

		local I0 I1 I2
		get_data 3 I $(eval echo \$_router$_idx)
		json_add_string "ip" "$I0"
		json_add_string "ping" "$I1"
		json_add_string "hostname" "$I2"

		json_add_array "ipv6"
		_idxf=$(get_index_array "$_MACS6" "$_rmac")
		if [ $_idxf ]
		then
			for _i6 in $(eval echo \$_6router$_idxf)
			do
				json_add_string "" "$_i6"
			done
		fi
		json_close_array

		_dhcp_signature=""
		_dhcp_vendor_class=""
		if [ -e "/tmp/dhcpinfo/$_rmac" ]
		then
			local D0 D1
			get_data 2 D $(cat /tmp/dhcpinfo/$_rmac)
			_dhcp_signature="$D0"
			_dhcp_vendor_class="$D1"
		fi

		json_add_string "conn_type" "0"
		json_add_string "conn_speed" ""
		json_add_string "dhcp_signature" "$_dhcp_signature"
		json_add_string "dhcp_vendor_class" "$_dhcp_vendor_class"
		json_close_object
		_processed_macs="$_processed_macs $_rmac"
	done

	# 3. Send cable ipv6 devs
	for _mac in $_MACS6
	do
		local _idxf
		local _idx=${_mac##*:}
		local _rmac=${_mac%:*}

		case "$_processed_macs" in
			*"$_rmac"*) continue;;
		esac

		json_add_object "$_rmac"

		json_add_array "ipv6"
		_idxf=$(get_index_array "$_MACS6" "$_rmac")
		if [ $_idxf ]
		then
			for _i6 in $(eval echo \$_6router$_idxf)
			do
				json_add_string "" "$_i6"
			done
		fi
		json_close_array

		_dhcp_signature=""
		_dhcp_vendor_class=""
		if [ -e "/tmp/dhcpinfo/$_rmac" ]
		then
			local D0 D1
			get_data 2 D $(cat /tmp/dhcpinfo/$_rmac)
			_dhcp_signature="$D0"
			_dhcp_vendor_class="$D1"
		fi

		json_add_string "conn_type" "0"
		json_add_string "conn_speed" ""
		json_add_string "dhcp_signature" "$_dhcp_signature"
		json_add_string "dhcp_vendor_class" "$_dhcp_vendor_class"
		json_close_object
		_processed_macs="$_processed_macs $_rmac"
	done

	json_close_object

	#Cleanup
	local _idx=0
	while [ $_idx -lt $_NUMACSW ]; do eval unset _wireless$_idx; _idx=$((_idx+1)); done
	_idx=0
	while [ $_idx -lt $_NUMACS4 ]; do eval unset _router$_idx; _idx=$((_idx+1)); done
	_idx=0
	while [ $_idx -lt $_NUMACS6 ]; do eval unset _6router$_idx; _idx=$((_idx+1)); done
}

get_online_mesh_routers() {
	local _stations=""
	local _iface=""

	_stations="$(iwinfo $(get_station_ifname 0) assoclist)"
	[ "$(echo "$_stations" | grep -v "No station connected")" ] || _stations=""
	_iface="0"

	if [ -z "$_stations" ] && [ "$(is_5ghz_capable)" == "1" ]
	then
		_stations="$(iwinfo $(get_station_ifname 1) assoclist)"
		[ "$(echo "$_stations" | grep -v "No station connected")" ] || _stations=""
		_iface="1"
	fi

	json_add_object "mesh_routers"
	if [ "$_stations" ]
	then
		local R0 R1 R2 R3
		_data="$(echo "$_stations"| awk 'NR==1{ print $1, $2 } /RX:/{ print $2 } /TX:/{ print $2 }')"
		get_data 4 R $_data
		json_add_object "$R0"
		json_add_string "signal" "$R1"
		json_add_string "rx_bit" "$R2"
		json_add_string "tx_bit" "$R3"
		json_add_string "conn_time" "0"
		json_add_string "rx_bytes" "$(cat /sys/class/net/$(get_station_ifname $_iface)/statistics/rx_bytes)"
		json_add_string "tx_bytes" "$(cat /sys/class/net/$(get_station_ifname $_iface)/statistics/tx_bytes)"
		json_add_string "iface" "$_iface"
		json_close_object
	fi
	json_close_object
}

send_online_devices() {
	[ "$(type -t get_mesh_mode)" ] || . /usr/share/functions/mesh_functions.sh

	local _res

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
