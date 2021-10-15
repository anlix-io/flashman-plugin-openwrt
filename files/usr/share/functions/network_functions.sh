#!/bin/sh

. /usr/share/flashman_init.conf
. /usr/share/functions/common_functions.sh
. /usr/share/functions/dhcp_functions.sh
. /usr/share/libubox/jshn.sh
. /lib/functions/network.sh
. /usr/share/functions/device_functions.sh
if [ -e /usr/share/functions/custom_device.sh ]; then
	. /usr/share/functions/custom_device.sh
fi

get_ipv6_enabled() {
	local _ipv6_enabled=1
	if [ "$(get_bridge_mode_status)" != "y" ]
	then
		[ "$(uci -q get network.wan.ipv6)" = "0" ] && _ipv6_enabled=0
	else
		[ "$(uci -q get network.lan.ipv6)" = "0" ] && _ipv6_enabled=0
	fi
	echo "$_ipv6_enabled"
}

enable_ipv6() {
	if [ "$(get_bridge_mode_status)" != "y" ]
	then
		uci set network.wan.ipv6="auto"
		uci set network.wan6.proto="dhcpv6"
		[ "$(uci -q get network.lan.ipv6)" ] && uci delete network.lan.ipv6
		[ "$(uci -q get network.lan6)" ] && uci delete network.lan6
	else
		uci set network.wan.ipv6="auto"
		uci set network.wan6.proto="none"
		uci set network.lan.ipv6="auto"
		if [ -z "$(uci -q get network.lan6)" ]
		then
			uci set network.lan6=interface
			uci set network.lan6.ifname='@lan'
		fi
		uci set network.lan6.proto='dhcpv6'
	fi
	uci commit network
	json_cleanup
	json_load_file /root/flashbox_config.json
	json_add_string enable_ipv6 "1"
	json_dump > /root/flashbox_config.json
	json_close_object
}

disable_ipv6() {
	uci set network.wan.ipv6="0"
	uci set network.wan6.proto='none'
	uci set network.lan.ipv6="0"
	[ "$(uci -q get network.lan6)" ] && uci delete network.lan6
	uci commit network
	json_cleanup
	json_load_file /root/flashbox_config.json
	json_add_string enable_ipv6 "0"
	json_dump > /root/flashbox_config.json
	json_close_object
}


diagnose_wan_connectivity() {
	local _status=""
	local _ip=""
	local _gateway=""
	local _hasconn=""
	if [ "$(get_bridge_mode_status)" != "y" ]
	then
		# Not in bridge mode, WAN must be configured
		_status="$(ifstatus wan)"
	else
		# Bridge mode enabled, WAN is not configured, so we use the LAN as a base
		_status="$(ifstatus lan)"
	fi
	_ip="$(echo "$_status" | jsonfilter -e '@["ipv4-address"][0].address')"
	_gateway="$(echo "$_status" | jsonfilter -e '@["route"][0].nexthop')"
	if [ "$_ip" = "" ]
	then
		echo 1
		return
	fi
	if [ "$_gateway" = "" ]
	then
		echo 2
		return
	fi
	_hasconn="$(check_connectivity_internet $_gateway)"
	if [ "$_hasconn" != "0" ]
	then
		echo 3
		return
	fi
	echo 0
	return
}

check_connectivity_ipv4() {
	local _addrs="8.8.8.8"$'\n'"200.132.0.132"
	check_connectivity_internet "$_addrs"
}

check_connectivity_ipv6() {
	local _ip="2001:4860:4860::8888"
	local _ipv6_connectivity=1

	if [ "$(get_ipv6_enabled)" != "0" ]
	then
		if ping6 -q -c 1 -w 2 "$_ip" > /dev/null 2>&1
		then
			_ipv6_connectivity=0
		fi
	fi
	echo $_ipv6_connectivity
}

check_connectivity_flashman() {
	_addrs="$FLM_SVADDR"
	check_connectivity_internet "$_addrs"
}

# check_connectivity_internet() {
# 	_addrs="www.google.com.br"$'\n'"www.facebook.com"$'\n'"www.globo.com"
# 	if [ "$1" != "" ]
# 	then
# 		_addrs="$1"
# 	fi
# 	for _addr in $_addrs
# 	do
# 		if ping -q -c 1 -w 2 "$_addr"  > /dev/null 2>&1
# 		then
# 			# true
# 			echo 0
# 			return
# 		fi
# 	done
# 	# No successfull pings

# 	# false
# 	echo 1
# 	return
# }

check_connectivity_internet() {
	_addrs="www.google.com.br"$'\n'"www.facebook.com"$'\n'"www.globo.com"
	if [ "$1" != "" ]
	then
		_addrs="$1"
	fi
	local collect_enabled="$2"
	for _addr in $_addrs
	do
		# ping output will be use in case collecting connectivity pings is enabled.
		local pingResult
		if pingResult=$(ping -q -c 1 -w 2 "$_addr")
		then
			# won't collect connectivity ping if data collecting service is not running.
			[ "$collect_enabled" -eq 1 ] && service data_collecting running && \
				save_connectivity_ping "$pingResult"

			# true
			echo 0
			return
		fi
	done
	# No successfull pings

	# false
	echo 1
	return
}

# expects the output of ping, that includes the pings statistics at the end, as a single string input.
# writes the ping rtt to a file inside the data_collecting directory.
save_connectivity_ping() {
	local pingResult="$1"

	# data_collecting directory
	local data_collecting_dir="/tmp/data_collecting"
	# file where pings are stored.
	local connectivityPingsFile="${data_collecting_dir}/connpings"

	# Removes everything before, and including, 'mdev = '.
	local rtt=${pingResult##*mdev = }
	# removes everything after, and including, first forward slash.
	rtt=${rtt%%/*}

	# using a lock file, in writing mode, to block code while accessing the pings file.
	# this is because the data_collecting service will also write to the pings file.
	{
	flock -x 9
	# creates data_collecting temporary directory if it doesn't exist.
	mkdir -p "$data_collecting_dir"
	# appending $rtt in a new line in pings file.
	echo "$rtt" >> "$connectivityPingsFile"
	# "${connectivityPingsFile}lock" is also used by the data_collecting service.
	} 9>"${connectivityPingsFile}lock"
}

renew_dhcp() {
	local _iface
	local _proto
	if [ "$(get_bridge_mode_status)" = "y" ]
	then
		_iface="lan"
		_proto="$(ifstatus $_iface | jsonfilter -e '@.proto')"
		[ "$_proto" = "dhcp" ] && ubus call "network.interface.$_iface" renew
	elif [ "$FLM_DO_DHCP_RENEW_ON_DISCONNECT" = "y" ]
	then
		_iface="wan"
		_proto="$(ifstatus $_iface | jsonfilter -e '@.proto')"
		[ "$_proto" = "dhcp" ] && ubus call "network.interface.$_iface" renew
	fi
}

get_wan_ip() {
	local _ip=""
	if [ "$(get_bridge_mode_status)" != "y" ]
	then
		network_get_ipaddr _ip wan
	else
		# Do not write "none" in case of bridge
		_ip="$(get_lan_bridge_ipaddr)"
	fi
	echo "$_ip"
}

get_wan_type() {
	echo "$(uci get network.wan.proto | awk '{ print tolower($1) }')"
}

set_wan_type() {
	local _wan_type=$(get_wan_type)
	local _wan_type_remote=$1
	local _pppoe_user_remote=$2
	local _pppoe_password_remote=$3
	local _wait_uhttpd_reply=$4 # TODO: Find a better way to solve this
	local _did_change_bridge="n"

	if [ "$_wait_uhttpd_reply" = "y" ]
	then
		sleep 3
	fi

	if [ "$_wan_type" = "none" ]
	then
		# Must disable bridge mode before changing wan configuration
		log "FLASHMAN UPDATER" "Disabling bridge mode to change WAN config ..."
		disable_bridge_mode "y"
		_did_change_bridge="y"
	fi

	if [ "$_wan_type_remote" != "$_wan_type" ]
	then
		if [ "$_wan_type_remote" = "dhcp" ]
		then
			log "FLASHMAN UPDATER" "Updating connection type to DHCP ..."
			uci set network.wan.proto="dhcp"
			uci set network.wan.username=""
			uci set network.wan.password=""
			uci set network.wan.service=""
			uci commit network

			/etc/init.d/network restart
			[ "$(get_ipv6_enabled)" != "0" ] && /etc/init.d/odhcpd restart # Must restart to fix IPv6 leasing

			# This will persist connection type between firmware upgrades
			json_cleanup
			json_load_file /root/flashbox_config.json
			json_add_string wan_conn_type "dhcp"
			json_add_string pppoe_user ""
			json_add_string pppoe_pass ""
			json_dump > /root/flashbox_config.json
			json_close_object

			# If we changed bridge and router needs reboot, we do so here
			if [ "$_did_change_bridge" = "y" ] && [ "$(type -t needs_reboot_change_mode)" ]
			then
				needs_reboot_change_mode
			fi

		elif [ "$_wan_type_remote" = "pppoe" ]
		then
			if [ "$_pppoe_user_remote" != "" ] && [ "$_pppoe_password_remote" != "" ]
			then
				log "FLASHMAN UPDATER" "Updating connection type to PPPOE ..."
				uci set network.wan.proto="pppoe"
				uci set network.wan.username="$_pppoe_user_remote"
				uci set network.wan.password="$_pppoe_password_remote"
				uci set network.wan.service="$FLM_WAN_PPPOE_SERVICE"
				uci set network.wan.keepalive="60 3"
				uci commit network

				/etc/init.d/network restart
				[ "$(get_ipv6_enabled)" != "0" ] && /etc/init.d/odhcpd restart # Must restart to fix IPv6 leasing

				# This will persist connection type between firmware upgrades
				json_cleanup
				json_load_file /root/flashbox_config.json
				json_add_string wan_conn_type "pppoe"
				json_add_string pppoe_user "$_pppoe_user_remote"
				json_add_string pppoe_pass "$_pppoe_password_remote"
				json_dump > /root/flashbox_config.json
				json_close_object

				# If we changed bridge and router needs reboot, we do so here
				if [ "$_did_change_bridge" = "y" ] && [ "$(type -t needs_reboot_change_mode)" ]
				then
					needs_reboot_change_mode
				fi

			fi
		fi
		# Don't put anything outside here. _content_type may be corrupted
	fi
}

set_pppoe_credentials() {
	local _wan_type=$(get_wan_type)
	local _pppoe_user_remote=$1
	local _pppoe_password_remote=$2
	local _wait_uhttpd_reply=$3 # TODO: Find a better way to solve this
	local _pppoe_user_local=$(uci -q get network.wan.username)
	local _pppoe_password_local=$(uci -q get network.wan.password)

	if [ "$_wait_uhttpd_reply" = "y" ]
	then
		sleep 3
	fi

	if [ "$_wan_type" = "pppoe" ]
	then
		if [ "$_pppoe_user_remote" != "" ] && [ "$_pppoe_password_remote" != "" ]
		then
			if [ "$_pppoe_user_remote" != "$_pppoe_user_local" ] || \
				 [ "$_pppoe_password_remote" != "$_pppoe_password_local" ]
			then
				log "FLASHMAN UPDATER" "Updating PPPoE ..."
				uci set network.wan.username="$_pppoe_user_remote"
				uci set network.wan.password="$_pppoe_password_remote"
				uci commit network

				/etc/init.d/network restart
				[ "$(get_ipv6_enabled)" != "0" ] && /etc/init.d/odhcpd restart # Must restart to fix IPv6 leasing

				# This will persist connection type between firmware upgrades
				json_cleanup
				json_load_file /root/flashbox_config.json
				json_add_string wan_conn_type "pppoe"
				json_add_string pppoe_user "$_pppoe_user_remote"
				json_add_string pppoe_pass "$_pppoe_password_remote"
				json_dump > /root/flashbox_config.json
				json_close_object
			fi
		fi
	fi
}

valid_ip() {
	local ip=$1
	local filtered_ip
	local stat=1
	local b1
	local b2
	local b3
	local b4

	filtered_ip=$(printf "%s\n" "$ip" |
								grep -E '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$')

	if [ "$filtered_ip" != "" ]
	then
		b1="$(echo $ip | awk -F. '{print $1}')"
		b2="$(echo $ip | awk -F. '{print $2}')"
		b3="$(echo $ip | awk -F. '{print $3}')"
		b4="$(echo $ip | awk -F. '{print $4}')"

		[[ $b1 -le 255 && $b2 -le 255 && $b3 -le 255 && $b4 -le 255 ]]
		stat=$?
	fi
	return $stat
}

get_lan_subnet() {
	local _ipcalc_res
	local _uci_lan_ipaddr
	local _uci_lan_netmask
	local _lan_addr
	_uci_lan_ipaddr=$(uci get network.lan.ipaddr)
	_uci_lan_netmask=$(uci get network.lan.netmask)
	_ipcalc_res="$(/bin/ipcalc.sh $_uci_lan_ipaddr $_uci_lan_netmask)"
	_lan_addr="$(echo "$_ipcalc_res" | grep "NETWORK" | awk -F= '{print $2}')"

	echo "$_lan_addr"
}

get_lan_bridge_ipaddr() {
	echo "$(ifstatus lan | jsonfilter -e '@["ipv4-address"][0]["address"]')"
}

get_lan_ipaddr() {
	local _uci_lan_ipaddr
	_uci_lan_ipaddr=$(uci get network.lan.ipaddr)
	echo "$_uci_lan_ipaddr"
}

get_lan_netmask() {
	local _ipcalc_res
	local _uci_lan_ipaddr
	local _uci_lan_netmask
	local _lan_netmask
	_uci_lan_ipaddr=$(uci get network.lan.ipaddr)
	_uci_lan_netmask=$(uci get network.lan.netmask)
	_ipcalc_res="$(/bin/ipcalc.sh $_uci_lan_ipaddr $_uci_lan_netmask)"
	_lan_netmask="$(echo "$_ipcalc_res" | grep "PREFIX" | awk -F= '{print $2}')"

	echo "$_lan_netmask"
}

set_lan_subnet() {
	local _lan_addr
	local _lan_netmask
	local _lan_net
	local _retstatus
	local _ipcalc_res
	local _ipcalc_netmask
	local _ipcalc_addr
	local _current_lan_ipaddr=$(get_lan_ipaddr)
	_lan_addr=$1
	_lan_netmask=$2

	# Validate LAN gateway address
	valid_ip "$_lan_addr"
	_retstatus=$?
	if [ $_retstatus -eq 0 ]
	then
		_ipcalc_res="$(/bin/ipcalc.sh $_lan_addr $_lan_netmask 1 255)"

		_ipcalc_netmask=$(echo "$_ipcalc_res" | grep "PREFIX" | \
											awk -F= '{print $2}')
		# Accepted netmasks: 24 to 26
		if [ $_ipcalc_netmask -ge 24 ] && [ $_ipcalc_netmask -le 26 ]
		then
			# Valid netmask
			_lan_netmask="$_ipcalc_netmask"
			# Use first address available returned by ipcalc
			_ipcalc_addr=$(echo "$_ipcalc_res" | grep "IP" | awk -F= '{print $2}')
			_lan_net=$(echo "$_ipcalc_res" | grep "NETWORK" | awk -F= '{print $2}')
			# Avoid placing subnet IP by mistake
			if [ "$_lan_net" = "$_ipcalc_addr" ]
			then
				_ipcalc_addr=$(echo "$_ipcalc_res" | grep "START" | awk -F= '{print $2}')
			fi
			# Assign LAN router ip
			_lan_addr="$_ipcalc_addr"
			# Calculate DHCP start and limit
			_addr_net=$(echo "$_ipcalc_res" | grep "NETWORK" | awk -F. '{print $4}')
			_addr_end=$(echo "$_ipcalc_res" | grep "END" | awk -F. '{print $4}')
			_addr_limit=$(( (_addr_end - _addr_net) / 2 ))
			_addr_start=$(( _addr_end - _addr_limit ))

			# DMZ lan is forbidden
			local _dmzprefix="$(echo $_lan_net | awk -F. '{print $1$2$3}')"
			if [ "$_dmzprefix" = "19216843" ]
			then
				# Error. DMZ is forbidden
				return 1
			fi

			# Only change LAN if its not the same
			if [ "$_lan_addr" != "$_current_lan_ipaddr" ]
			then
				uci set network.lan.ipaddr="$_lan_addr"
				uci set network.lan.netmask="$_lan_netmask"
				uci commit network
				uci set dhcp.lan.start="$_addr_start"
				uci set dhcp.lan.limit="$_addr_limit"
				uci commit dhcp

				# Replace IP so Flash App can find the router
				sed -i 's/.*anlixrouter/'"$_lan_addr"' anlixrouter/' /etc/hosts

				/etc/init.d/network restart
				[ "$(get_ipv6_enabled)" != "0" ] && /etc/init.d/odhcpd restart # Must restart to fix IPv6 leasing
				/etc/init.d/dnsmasq reload
				/etc/init.d/uhttpd restart # Must restart to update Flash App API
				/etc/init.d/minisapo reload
				/etc/init.d/miniupnpd reload

				# Save LAN config
				json_cleanup
				json_load_file /root/flashbox_config.json
				json_add_string lan_addr "$_lan_net"
				json_add_string lan_netmask "$_lan_netmask"
				json_dump > /root/flashbox_config.json
				json_close_object

				return 0
			else
				# No change
				return 1
			fi
		else
			# Parse error
			return 1
		fi
	else
		# Parse error
		return 1
	fi
}

# Arg 1: IP address to check, Arg 2: LAN subnet, Arg 3: LAN netmask
is_ip_in_lan() {
	local _device_ip
	local _lan_subnet
	local _lan_netmask
	local _ipcalc_res
	local _ipcalc_addr

	if [ $# -eq 3 ] && [ "$1" ]
	then
		_device_ip=$1
		_lan_subnet=$2
		_lan_netmask=$3
		_ipcalc_res="$(/bin/ipcalc.sh $_lan_subnet $_lan_netmask $_device_ip)"
		_ipcalc_addr=$(echo "$_ipcalc_res" | grep "START" | awk -F= '{print $2}')
		if [ "$_ipcalc_addr" = "$_device_ip" ]
		then
			# IP belongs to LAN subnet
			return 0
		else
			# No match
			return 1
		fi
	else
		# Error
		return 1
	fi
}

add_static_ipv6() {
	local _mac=$1

	# do not create new entry
	local i=0
	local _idtmp=$(uci -q get dhcp.@host[$i].mac)
	while [ $? -eq 0 ]; do
		if [ "$_idtmp" = "$_mac" ]
		then
			local _addr=$(uci -q get dhcp.@host[$i].hostid)
			if [ ! -z "$_addr" ]
			then
				echo "$_addr"
				return
			fi
		fi
		i=$((i+1))
		_idtmp=$(uci -q get dhcp.@host[$i].mac)
	done

	# no entry found, create new
	local _dhcp_ipv6=$(get_ipv6_dhcp | grep "$_mac")
	if [ -n "$_dhcp_ipv6" ]
	then
		local _duid=$(echo "$_dhcp_ipv6" | awk '{print $1}')
		local _addr=$(echo "$_dhcp_ipv6" | awk '{print $3}')

		uci -q add dhcp host > /dev/null
		uci -q set dhcp.@host[-1].mac="$_mac"
		uci -q set dhcp.@host[-1].duid="$_duid"
		uci -q set dhcp.@host[-1].hostid="${_addr#*::}"
		uci -q commit dhcp

		#return just the first
		echo "${_addr#*::}"
	fi
}

add_static_ip() {
	local _mac=$1
	local _dmz=$2
	local _ethers_file="$3"
	local _ipv4_neigh="$(ip -4 neigh | grep lladdr | awk '{ if($3 == "br-lan") print $5, $1}')"
	local _device_ip="$(echo "$_ipv4_neigh" | grep "$_mac" | awk '{ print $2 }')"
	local _lan_subnet=$(get_lan_subnet)
	local _lan_netmask=$(get_lan_netmask)
	local _dmz_subnet="192.168.43.0"
	local _dmz_netmask="24"
	local _device_on_lan
	local _device_on_dmz
	local _fixed_ip
	local _ipcalc_res
	local _next_addr=""

	is_ip_in_lan "$_device_ip" "$_lan_subnet" "$_lan_netmask"
	_device_on_lan=$?
	is_ip_in_lan "$_device_ip" "$_dmz_subnet" "$_dmz_netmask"
	_device_on_dmz=$?

	# Device is online. Use the same ip address
	if [ "$_device_ip" ]
	then
		if { [ "$_dmz" = "1" ] && [ $_device_on_dmz -eq 0 ]; } || \
			 { [ "$_dmz" = "0" ] && [ $_device_on_lan -eq 0 ]; }
		then
			echo "$_mac $_device_ip" >> /etc/$_ethers_file
			echo "$_device_ip"
			return
		fi
	fi

	# Device is offline. Choose an ip address
	if [ "$_dmz" = "1" ]
	then
		if [ -f /etc/$_ethers_file ]
		then
			while read _fixed_ip
			do
				_fixed_ip="$(echo "$_fixed_ip" | awk '{print $2}')"
				is_ip_in_lan "$_fixed_ip" "$_dmz_subnet" "$_dmz_netmask"
				if [ $? -eq 0 ]
				then
					_ipcalc_res="$(/bin/ipcalc.sh $_dmz_subnet \
												 $_dmz_netmask $_fixed_ip 1)"
					_next_addr="$(echo "$_ipcalc_res" | grep "END" | \
												awk -F= '{print $2}')"
				fi
			done < /etc/$_ethers_file
			if [ "$_next_addr" = "" ]
			then
				# It must start at 130 to isolate routes
				_ipcalc_res="$(/bin/ipcalc.sh $_dmz_subnet $_dmz_netmask 1 129)"
				_next_addr="$(echo "$_ipcalc_res" | grep "END" | awk -F= '{print $2}')"
			fi
		else
			# It must start at 130 to isolate routes
			_ipcalc_res="$(/bin/ipcalc.sh $_dmz_subnet $_dmz_netmask 1 129)"
			_next_addr="$(echo "$_ipcalc_res" | grep "END" | awk -F= '{print $2}')"
		fi
	else
		if [ -f /etc/$_ethers_file ]
		then
			while read _fixed_ip
			do
				_fixed_ip="$(echo "$_fixed_ip" | awk '{print $2}')"
				is_ip_in_lan "$_fixed_ip" "$_lan_subnet" "$_lan_netmask"
				if [ $? -eq 0 ]
				then
					_ipcalc_res="$(/bin/ipcalc.sh $_lan_subnet \
												 $_lan_netmask $_fixed_ip 1)"
					_next_addr="$(echo "$_ipcalc_res" | grep "END" | \
												awk -F= '{print $2}')"
				fi
			done < /etc/$_ethers_file
			if [ "$_next_addr" = "" ]
			then
				_ipcalc_res="$(/bin/ipcalc.sh $_lan_subnet $_lan_netmask 1 1)"
				_next_addr="$(echo "$_ipcalc_res" | grep "END" | awk -F= '{print $2}')"
			fi
		else
			_ipcalc_res="$(/bin/ipcalc.sh $_lan_subnet $_lan_netmask 1 1)"
			_next_addr="$(echo "$_ipcalc_res" | grep "END" | awk -F= '{print $2}')"
		fi
	fi
	echo "$_mac $_next_addr" >> /etc/$_ethers_file
	echo "$_next_addr"
}

get_use_dns_proxy() {
	local _current_dnsproxy

	_current_dnsproxy="$(uci get dhcp.@dnsmasq[0].noproxy)"
	if [ $? -eq 0 ]
	then
		echo "$_current_dnsproxy"
	else
		# If not set than use default
		echo "$FLM_DHCP_NOPROXY"
	fi
}

set_use_dns_proxy() {
	local _no_dnsproxy
	local _current_dnsproxy

	_no_dnsproxy=$1
	if [ "$_no_dnsproxy" != "1" ] && [ "$_no_dnsproxy" != "0" ]
	then
		# Invalid value
		return
	fi

	_current_dnsproxy="$(uci get dhcp.@dnsmasq[0].noproxy)"
	if [ $? -eq 0 ]
	then
		if [ "$_current_dnsproxy" != "$_no_dnsproxy" ]
		then
			if [ "$_no_dnsproxy" == "1" ]
			then
				uci set dhcp.@dnsmasq[0].noproxy='1'
			else
				uci set dhcp.@dnsmasq[0].noproxy='0'
			fi
			uci commit dhcp
			/etc/init.d/dnsmasq reload
			[ "$(get_ipv6_enabled)" != "0" ] && /etc/init.d/odhcpd reload
		fi
	fi

	return
}

store_wan_bytes() {
	local _epoch=$(date +%s)
	local _wan_rx=$(get_wan_statistics RX)
	local _wan_tx=$(get_wan_statistics TX)

	json_init

	if [ -f /tmp/wanbytes.json ]
	then
		local _size=$(ls -l /tmp/wanbytes.json | awk '{print $5}')
		if [ $_size -lt 8196 ]
		then
			json_load_file /tmp/wanbytes.json
			json_select "wanbytes"
		else
			json_add_object "wanbytes"
		fi
	else
		json_add_object "wanbytes"
	fi

	json_add_array "$_epoch"
	json_add_int "" "$_wan_rx"
	json_add_int "" "$_wan_tx"
	json_close_array
	json_close_object
	json_dump > /tmp/wanbytes.json
	json_cleanup
}

get_bridge_mode_status() {
	local _status=""
	json_cleanup
	json_load_file /root/flashbox_config.json
	json_get_var _status bridge_mode
	json_close_object
	echo "$_status"
}

update_vlan() {
	if [ -f /root/vlan_config.json ]; then
		local _restart_network=$1
		json_cleanup
		json_load_file /root/vlan_config.json
		json_get_keys _vlans

		# On first boot there will be no vlan object
		if [ "$_vlans" != "" ]; then

			local _input=""
			_input="$(uci show network | grep ].vlan=)"

			IFS=$'\n'

			local _vids=''
			local _idx=0

			for _vlan in $_input; do
				_vid=${_vlan#*\'}
				_vid=${_vid%\'}
				local _test=${_vlans#*$_vid}
				# Indicates _vid is in _vlans
				if [ $(( ${#_test} < ${#_vlans} )) = 1 ]; then
					json_get_var _ports $_vid
					uci set network.@switch_vlan[$_idx].ports="$_ports"
				else # _vid isn't in _vlans
					uci delete network.@switch_vlan[$_idx]
					_idx=$(( _idx - 1 ))
				fi
				if [ "$_vids" = '' ]; then
					_vids="$_vid"
				else
					_vids="$_vids $_vid"
				fi
				_idx=$(( _idx + 1 ))
			done

			IFS=$' '

			for _vlan in $_vlans; do
				_test=${_vids#*$_vlan}
				# Indicates _vlan isn't in _vids
				if [ $(( ${#_test} < ${#_vids} )) = 0 ]; then
					json_get_var _ports $_vlan
					uci add network switch_vlan
					uci set network.@switch_vlan[-1].device="$(get_switch_device)"
					uci set network.@switch_vlan[-1].vlan="$_vlan"
					uci set network.@switch_vlan[-1].ports="$_ports"
				fi
			done

			uci commit network
			[ "$_restart_network" = "y" ] && /etc/init.d/network restart && sleep 5
		fi

		json_close_object
	fi
}

enable_bridge_mode() {
	local _do_network_restart=$1
	local _wait_uhttpd_reply=$2 # TODO: Find a better way to solve this
	local _disable_lan_ports=$3
	local _fixed_ip=$4
	local _fixed_gateway=$5
	local _fixed_dns=$6

	if [ "$_wait_uhttpd_reply" = "y" ]
	then
		sleep 3
	fi

	# Get ifnames to bridge them together
	local _lan_ip="$(uci get network.lan.ipaddr)"
	local _lan_ifnames="$(uci get network.lan.ifname)"
	local _wan_ifnames="$(uci get network.wan.ifname)"
	# Write bridge mode to config.json so it persists between flashes
	json_cleanup
	json_load_file /root/flashbox_config.json
	json_get_var _enable_ipv6 enable_ipv6
	json_add_string bridge_mode "y"
	json_add_string bridge_lan_backup "$_lan_ifnames"
	json_add_string bridge_lan_ip_backup "$_lan_ip"
	json_add_string bridge_disable_switch "$_disable_lan_ports"
	json_add_string bridge_fix_ip "$_fixed_ip"
	json_add_string bridge_fix_gateway "$_fixed_gateway"
	json_add_string bridge_fix_dns "$_fixed_dns"
	json_dump > /root/flashbox_config.json
	json_close_object
	# Disable wan and bridge interfaces in lan
	uci set network.wan.proto="none"
	uci set network.wan6.proto="none"

	if [ "$_enable_ipv6" = "1" ]
	then
		uci set network.lan.ipv6="auto"
		if [ -z "$(uci -q get network.lan6)" ]
		then
			uci set network.lan6=interface
			uci set network.lan6.ifname='@lan'
		fi
		uci set network.lan6.proto='dhcpv6'
	else
		uci set network.lan.ipv6="0"
		[ "$(uci -q get network.lan6)" ] && uci delete network.lan6
	fi

	if [ "$_fixed_ip" != "" ]
	then
		uci set network.lan.ipaddr="$_fixed_ip"
		uci set network.lan.gateway="$_fixed_gateway"
		uci set network.lan.dns="$_fixed_dns"
		# Replace LAN IP so Flash App can find the router
		sed -i 's/.*anlixrouter/'"$_fixed_ip"' anlixrouter/' /etc/hosts
	else
		# LAN IP on etc/hosts will be replaced by hotplug
		uci set network.lan.proto="dhcp"
	fi

	if [ "$(type -t wan_lan_diff_ifaces)" == "" ]; then
		save_bridge_mode_vlan_config "y" "$_disable_lan_ports"
	else
		# those routers do not use vlan
		if [ "$_disable_lan_ports" = "y" ]
		then
			uci set network.lan.ifname="$_wan_ifnames"
		else
			# DO NOT PLACE WAN IFNAME BEFORE LAN IFNAME OR SOME ROUTERS WILL CRASH
			uci set network.lan.ifname="$_lan_ifnames $_wan_ifnames"
		fi
	fi

	# Disable dns, dhcp and dhcp6
	/etc/init.d/miniupnpd disable
	/etc/init.d/miniupnpd stop
	/etc/init.d/firewall disable
	/etc/init.d/firewall stop
	/etc/init.d/dnsmasq disable
	/etc/init.d/dnsmasq stop
	/etc/init.d/odhcpd disable
	/etc/init.d/odhcpd stop
	# Save changes and reboot network
	uci commit network
	if [ "$_do_network_restart" = "y" ]
	then
		if [ "$_fixed_ip" != "" ]
		then
			/etc/init.d/network restart
			# Wait for network to configure itself and check connectivity
			sleep 5
			_accessOK="$(check_connectivity_internet)"
			if [ "$_accessOK" = "1" ]
			then
				# No connectivity - remove fixed ip config from bridge
				json_cleanup
				json_load_file /root/flashbox_config.json
				json_add_string bridge_did_reset "y"
				json_add_string bridge_fix_ip ""
				json_add_string bridge_fix_gateway ""
				json_add_string bridge_fix_dns ""
				json_dump > /root/flashbox_config.json
				json_close_object
				uci set network.lan.proto="dhcp"
				uci set network.lan.ipaddr=""
				uci set network.lan.gateway=""
				uci set network.lan.dns=""
				uci commit network
			fi
		fi
		# Some targets need to reboot the whole router after changing mode
		if [ "$(type -t needs_reboot_change_mode)" ]
		then
			needs_reboot_change_mode
		else
			/etc/init.d/network restart
			/etc/init.d/uhttpd restart
			/etc/init.d/minisapo reload
		fi
	fi
}

update_bridge_mode() {
	local _wait_uhttpd_reply=$1 # TODO: Find a better way to solve this
	local _disable_lan_ports=$2
	local _fixed_ip=$3
	local _fixed_gateway=$4
	local _fixed_dns=$5

	if [ "$_wait_uhttpd_reply" = "y" ]
	then
		sleep 3
	fi

	local _current_switch=""
	local _current_ip=""
	local _current_gateway=""
	local _current_dns=""
	local _lan_ifnames=""
	local _reset_network="n"
	local _check_reboot="n"
	local _wan_ifnames="$(uci get network.wan.ifname)"
	json_cleanup
	json_load_file /root/flashbox_config.json
	json_get_var _current_switch bridge_disable_switch
	json_get_var _current_ip bridge_fix_ip
	json_get_var _current_gateway bridge_fix_gateway
	json_get_var _current_dns bridge_fix_dns
	# Update ip, gateway, dns if needed
	if [ "$_current_ip" != "$_fixed_ip" ]
	then
		_reset_network="y"
		if [ "$_fixed_ip" != "" ]
		then
			uci set network.lan.proto="static"
			uci set network.lan.ipaddr="$_fixed_ip"
		else
			uci set network.lan.proto="dhcp"
		fi
		json_add_string bridge_fix_ip "$_fixed_ip"
	fi
	if [ "$_current_gateway" != "$_fixed_gateway" ]
	then
		uci set network.lan.gateway="$_fixed_gateway"
		json_add_string bridge_fix_gateway "$_fixed_gateway"
		_reset_network="y"
	fi
	if [ "$_current_dns" != "$_fixed_dns" ]
	then
		uci set network.lan.dns="$_fixed_dns"
		json_add_string bridge_fix_dns "$_fixed_dns"
		_reset_network="y"
	fi
	# Update switch disable flag if needed
	if [ "$_current_switch" != "$_disable_lan_ports" ]
	then
		json_add_string bridge_disable_switch "$_disable_lan_ports"
		json_get_var _lan_ifnames bridge_lan_backup
		_reset_network="y"
		_check_reboot="y"

		if [ "$(type -t wan_lan_diff_ifaces)" == "" ]; then
			save_bridge_mode_vlan_config "y" "$_disable_lan_ports"
		else
			#routers that do not use vlan
			if [ "$_disable_lan_ports" = "y" ]
			then
				uci set network.lan.ifname="$_wan_ifnames"
			else
				# DO NOT PLACE WAN IFNAME BEFORE LAN IFNAME OR SOME ROUTERS WILL CRASH
				uci set network.lan.ifname="$_lan_ifnames $_wan_ifnames"
			fi
		fi
	fi
	json_dump > /root/flashbox_config.json
	json_close_object
	if [ "$_reset_network" = "y" ]
	then
		log "FLASHMAN UPDATER" "Updated parameters, restarting network..."
		uci commit network
		/etc/init.d/network restart
		if [ "$_fixed_ip" != "" ]
		then
			/etc/init.d/uhttpd restart
			# Wait for network to configure itself and check connectivity
			sleep 5
			_accessOK="$(check_connectivity_internet)"
			if [ "$_accessOK" = "1" ]
			then
				# No connectivity - remove fixed ip config from bridge
				json_cleanup
				json_load_file /root/flashbox_config.json
				json_add_string bridge_did_reset "y"
				json_dump > /root/flashbox_config.json
				json_close_object
				update_bridge_mode "n" "$2" "" "" ""
			fi
		fi
		# Some targets need to reboot the whole router after changes on switch
		if [ "$(type -t needs_reboot_change_mode)" ] && [ "$_check_reboot" == "y" ]
		then
			needs_reboot_change_mode
		fi
		/etc/init.d/minisapo reload
	else
		log "FLASHMAN UPDATER" "No changes in bridge parameters..."
	fi
}

disable_bridge_mode() {
	local _wan_conn_type=""
	local _lan_ifnames=""
	local _lan_ip=""
	local _skip_network_restart="$1"
	local _wait_uhttpd_reply="$2" # TODO: Find a better way to solve this

	if [ "$_wait_uhttpd_reply" = "y" ]
	then
		sleep 3
	fi

	# Clear bridge mode from config.json so it doesn't persist between flashes
	json_cleanup
	json_load_file /root/flashbox_config.json
	json_get_var _enable_ipv6 enable_ipv6
	json_get_var _wan_conn_type wan_conn_type
	json_get_var _lan_ifnames bridge_lan_backup
	json_get_var _lan_ip bridge_lan_ip_backup
	json_add_string bridge_mode "n"
	json_dump > /root/flashbox_config.json
	json_close_object
	# Test for empty wan_conn_type to avoid bugs after hard reset
	if [ "$_wan_conn_type" = "" ]
	then
		_wan_conn_type="$FLM_WAN_PROTO"
	fi

	# Save router mode vlan config
	if [ "$(type -t wan_lan_diff_ifaces)" == "" ]; then
		save_bridge_mode_vlan_config "n" "n"
	else
		# Router without vlan: Get ifname to remove from the bridge
		uci set network.lan.ifname="$_lan_ifnames"
	fi

	uci set network.lan.proto="static"
	uci set network.lan.ipaddr="$_lan_ip"
	# Set wan and lan back to proper values
	uci set network.wan.proto="$_wan_conn_type"

	if [ "$_enable_ipv6" = "1" ]
	then
		uci set network.wan.ipv6="auto"
		uci set network.wan6.proto="dhcpv6"
		[ "$(uci -q get network.lan.ipv6)" ] && uci delete network.lan.ipv6
	else
		uci set network.wan.ipv6="0"
		uci set network.wan6.proto='none'
		uci set network.lan.ipv6="0"
	fi
	[ "$(uci -q get network.lan6)" ] && uci delete network.lan6

	uci set network.lan.proto="static"
	uci delete network.lan.gateway
	uci delete network.lan.dns
	uci commit network
	/etc/init.d/miniupnpd enable
	/etc/init.d/miniupnpd start
	/etc/init.d/firewall enable
	/etc/init.d/firewall start
	/etc/init.d/dnsmasq enable
	/etc/init.d/dnsmasq start
	if [ "$_enable_ipv6" = "1" ]
	then
		/etc/init.d/odhcpd enable
		/etc/init.d/odhcpd start
	fi
	if [ "$_skip_network_restart" != "y" ]
	then
		# Some targets need to reboot the whole router after changing mode
		if [ "$(type -t needs_reboot_change_mode)" ]
		then
			needs_reboot_change_mode
		else
			/etc/init.d/network restart
			[ "$(get_ipv6_enabled)" = "1" ] && /etc/init.d/odhcpd restart
		fi
	fi
}

save_bridge_mode_vlan_config() {
	local _enable_bridge="$1"
	local _disable_lan_ports="$2"

	if [ "$(type -t custom_switch_ports)" ]; then
		local _wan_port=$(custom_switch_ports 2) 
		local _lan_ports=$(custom_switch_ports 3)
		local _cpu_port=$(custom_switch_ports 4) 
	else
		local _wan_port=$(switch_ports 2) 
		local _lan_ports=$(switch_ports 3)
		local _cpu_port=$(switch_ports 4) 
	fi

	if [ "$_enable_bridge" = "y" ]; then
		_vlan="{ \"1\": \"$_wan_port "
		if [ "$_disable_lan_ports" = "y" ]; then
			_vlan="$_vlan${_cpu_port}t\""
		else
			_vlan="$_vlan$_lan_ports ${_cpu_port}t\""
		fi
		_vlan="$_vlan, \"2\": \"\" }"
	else
		_vlan="{ \"1\": \"$_lan_ports ${_cpu_port}t\", \"2\": \"$_wan_port ${_cpu_port}t\" }"
	fi
	echo "$_vlan" > /root/vlan_config.json
	update_vlan "n"
}