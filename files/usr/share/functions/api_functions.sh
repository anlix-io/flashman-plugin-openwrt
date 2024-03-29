#!/bin/sh

. /usr/share/flashman_init.conf
. /usr/share/libubox/jshn.sh
. /usr/share/functions/common_functions.sh
. /usr/share/functions/device_functions.sh
. /usr/share/functions/firewall_functions.sh
. /usr/share/functions/network_functions.sh

send_boot_log() {
	local _res
	local _header="X-ANLIX-LOGS: NONE"

	if [ "$1" = "boot" ]
	then
		if [ -e /tmp/clean_boot ]
		then
			_header="X-ANLIX-LOGS: FIRST"
		else
			_header="X-ANLIX-LOGS: BOOT"
		fi
	fi
	if [ "$1" = "live" ]
	then
		_header="X-ANLIX-LOGS: LIVE"
	fi

	_res=$(logread | gzip | curl -s --tlsv1.2 --connect-timeout 5 \
				--retry 1 \
				-H "Content-Type: application/octet-stream" \
				-H "X-ANLIX-ID: $(get_mac)" -H "X-ANLIX-SEC: $FLM_CLIENT_SECRET" \
				-H "$_header"  --data-binary @- "https://$FLM_SVADDR/deviceinfo/logs")

	json_cleanup
	json_load "$_res"
	json_get_var _processed processed
	json_close_object

	return $_processed
}

reset_flashapp_pass() {
	json_cleanup
	json_load_file /root/flashbox_config.json
	json_get_var _flashapp_pass flashapp_pass

	if [ "$_flashapp_pass" != "" ]
	then
		json_add_string flashapp_pass ""
		json_dump > /root/flashbox_config.json
	fi

	json_close_object
}

get_flashapp_pass() {
	json_cleanup
	json_load_file /root/flashbox_config.json
	json_get_var _flashapp_pass flashapp_pass
	json_close_object

	echo "$_flashapp_pass"
}

set_flashapp_pass() {
	json_cleanup
	json_load_file /root/flashbox_config.json
	json_add_string flashapp_pass "$1"
	json_dump > /root/flashbox_config.json
	json_close_object
}

flashbox_ping() {
	local _host="$1"
	local _type="$2"
	local _out="$3"
	local _result=$(ping -q -i 0.01 -c 100 "$_host")
	local _latval=$(echo "$_result" | awk -F= 'NR==5 { print $2 }' | \
									awk -F/ '{ print $2 }')
	local _lossval=$(echo "$_result" | awk -F, 'NR==4 { print $3 }' | \
									awk '{ print $1 }' | awk -F% '{ print $1 }')

	if [ "$_type" = "lat" ]
	then
		if [ "$_out" = "json" ]
		then
			json_add_object "$_host"
			json_add_string "lat" "$_latval"
			json_close_object
		else
			echo "$_latval"
		fi
	elif [ "$_type" = "loss" ]
	then
		if [ "$_out" = "json" ]
		then
			json_add_object "$_host"
			json_add_string "loss" "$_lossval"
			json_close_object
		else
			echo "$_lossval"
		fi
	else
		if [ "$_out" = "json" ]
		then
			json_add_object "$_host"
			json_add_string "lat" "$_latval"
			json_add_string "loss" "$_lossval"
			json_close_object
		else
			echo "$_latval $_lossval"
		fi
	fi
}

flashbox_multi_ping() {
	local _hosts_file=$1
	local _hosts=""
	local _out=$2
	local _type=$3
	local _result=""
	local _lossval=""
	local _latval=""

	json_cleanup
	json_load_file "$_hosts_file"
	json_select "hosts"
	if [ "$?" -eq 1 ]
	then
		return
	fi
	local _idx="1"
	while json_get_type type "$_idx" && [ "$type" = string ]
	do
		json_get_var _hostaddr "$((_idx++))"
		_hosts="$_hostaddr"$'\n'"$_hosts"
	done
	json_select ".."
	json_close_object

	json_init
	json_add_object "results"
	# Don't put double quotes on _hosts variable!
	for _host in $_hosts
	do
		flashbox_ping "$_host" "$_type" "json"
	done
	json_close_object
	json_dump > "$_out"
	json_cleanup
}

run_ping_ondemand_test() {
	local _hosts_file="/tmp/hosts_file.json"
	local _out_file="/tmp/ping_result.json"
	local _data="id=$(get_mac)"
	local _url="deviceinfo/get/pinghosts"
	local _res
	local _retstatus
	_res=$(rest_flashman "$_url" "$_data")
	_retstatus=$?

	if [ $_retstatus -eq 0 ]
	then
		json_cleanup
		json_load "$_res"
		json_dump > "$_hosts_file"
		json_close_object
		json_cleanup

		flashbox_multi_ping "$_hosts_file" "$_out_file" "all"

		# Remove file
		rm "$_hosts_file"

		if [ -f "$_out_file" ]
		then
			local _file_content="$(cat "$_out_file")"
			_res=""
			_res=$(send_data_flashman "pingresult" "$_file_content")

			json_load "$_res"
			json_get_var _processed processed
			json_close_object

			rm "$_out_file"

			return $_processed
		else
			return 0
		fi
	fi
	return 0
}

sys_uptime() {
	echo "$(awk -F. '{print $1}' /proc/uptime)"
}

wan_uptime() {
	local _wan_uptime=0
	local _start_time

	json_cleanup
	if [ -f /tmp/ext_access_time.json ]
	then
		json_load_file /tmp/ext_access_time.json
		json_get_var _start_time starttime
		json_close_object
		[ -n "$_start_time" ] && _wan_uptime=$(($(sys_uptime)-$_start_time))
	fi

	echo "$_wan_uptime"
}

# Get the CPU usage
get_cpu_usage() {
	local _cpu=$(top -bn1 | awk '{if($1 ~ /^CPU:/){print int(100-$8)}}')
	echo "$_cpu"
}

# Get the Memory usage
get_memory_usage() {
	local _memory=$(free -m | awk '{if($1 ~ /^Mem:/){print int(($2-$4)*100/$2)}}')
	echo "$_memory"
}

router_status() {
	local _res
	local _processed
	local _sys_uptime
	local _wan_uptime
	local _cpu_usage
	local _memory_usage
	local _out_file="/tmp/router_status.json"

	_sys_uptime="$(sys_uptime)"
	_wan_uptime="$(wan_uptime)"
	_cpu_usage="$(get_cpu_usage)"
	_mem_usage="$(get_memory_usage)"


	json_init
	if [ -f /tmp/wanbytes.json ]
	then
		json_load_file /tmp/wanbytes.json
	fi
	json_add_string "sysuptime" "$_sys_uptime"
	json_add_string "wanuptime" "$_wan_uptime"
	json_add_object resources
	json_add_int "cpu_usage" "$_cpu_usage"
	json_add_int "mem_usage" "$_mem_usage"
	json_close_object
	json_dump > "$_out_file"
	json_cleanup

	if [ -f "$_out_file" ]
	then
		local _file_content="$(cat "$_out_file")"
		_res=""
		_res=$(send_data_flashman "routerstatus" "$_file_content")

		json_load "$_res"
		json_get_var _processed processed
		json_close_object

		rm "$_out_file"

		return $_processed
	else
		return 0
	fi
}

send_wan_info() {
	local _wan_conn_type
	local _dns_server
	local _default_gateway_v4
	local _default_gateway_v6
	local _pppoe_mac
	local _pppoe_ip
	local _ipv6
	local _ipv6_mask
	local _processed="0"

	# Set the values
	json_cleanup
	json_load_file /root/flashbox_config.json
	json_get_var _wan_conn_type wan_conn_type
	json_close_object

	_default_gateway_v4="$(get_gateway)"
	_default_gateway_v6="$(get_gateway6)"
	_dns_server="$(get_dns_server)"
	_pppoe_mac="$(get_pppoe_mac)"
	_pppoe_ip="$(get_pppoe_ip)"
	_ipv4="$(get_wan_ip)"
	_ipv4_mask="$(get_wan_ip_mask)"
	_ipv6="$(get_wan_ipv6)"
	_ipv6_mask="$(get_wan_ipv6_mask)"

	# Create the json
	json_cleanup
	json_init
	json_add_string "wan_conn_type" "$_wan_conn_type"
	json_add_string "default_gateway_v4" "$_default_gateway_v4"
	json_add_string "default_gateway_v6" "$_default_gateway_v6"
	json_add_string "dns_server" "$_dns_server"
	json_add_string "pppoe_mac" "$_pppoe_mac"
	json_add_string "pppoe_ip" "$_pppoe_ip"
	json_add_string "ipv4_address" "$_ipv4"
	json_add_string "ipv4_mask" "$_ipv4_mask"
	json_add_string "ipv6_address" "$_ipv6"
	json_add_string "ipv6_mask" "$_ipv6_mask"

	# Send the json
	local _json_content="$(json_dump)"
	_res=""
	_res=$(send_data_flashman "waninfo" "$_json_content")

	json_cleanup

	# Check server response
	if [ -n "$_res" ]
	then
		json_load "$_res"
		json_get_var _processed processed
		json_close_object
	fi
	json_cleanup

	return $_processed
}

send_lan_info() {
	local _prefix
	local _mask
	local _local_addr
	local _processed="0"

	# Set the values
	_prefix="$(get_prefix_delegation_addres)"
	_mask="$(get_prefix_delegation_mask)"
	_local_addr="$(get_prefix_delegation_local_address)"

	# Create the json
	json_init
	json_add_string "prefix_delegation_addr" "$_prefix"
	json_add_string "prefix_delegation_mask" "$_mask"
	json_add_string "prefix_delegation_local" "$_local_addr"

	# Send the json
	local _json_content="$(json_dump)"
	_res=""
	_res=$(send_data_flashman "laninfo" "$_json_content")

	json_cleanup

	# Check server response
	if [ -n "$_res" ]
	then
		json_load "$_res"
		json_get_var _processed processed
		json_close_object
	fi
	json_cleanup

	return $_processed
}

check_and_set_default_traceroute() {
	# $1: Variable value
	# $2: Minimum value
	# $3: Maximum value
	# $4: Default

	local _var="$1"

	if [ "$_var" -lt "$2" ]; then
		_var="$2"
	fi

	if [ "$_var" -gt "$3" ]; then
		_var="$3"
	fi

	if [ -z "$_var" ] || [ -n "$(echo "$_var" | grep -E '[^0-9]' )" ]; then
		_var="$4"
	fi

	echo "$_var"
}

create_time_object_traceroute() {
	# $1: ip
	# $2: hops
	local _ip="$1"
	local _hops="$2"

	json_add_object
	json_add_string ip "$_ip"

	# Create an array for storing the times
	json_add_array ms_values

	# Get all values with ms than remove the ms
	local _times="$(echo "$_hops" | grep -E -o '[0-9]+\.[0-9]+ ms' | grep -E -o '[0-9]+\.[0-9]+')"

	for _time in $_times
	do
		json_add_string "" "$_time"
	done

	json_close_array
	json_close_object
}

get_traceroute() {
	# $1: Max Hops
	# $2: Number of probes per hop
	# $3: Time in seconds to wait for a response
	local _route=""
	local _max_hops="$1"
	local _nprobes="$2"
	local _trace_time="$3"

	# Get the hosts
	# Attention: Using the same hosts of ping
	local _url="deviceinfo/get/pinghosts"
	local _data="id=$(get_mac)"
	_res=$(rest_flashman "$_url" "$_data")

	# Verify the response
	local _resstatus=$?
	if [ $_resstatus -ne 0 ]
	then
		return 0
	fi

	local _hosts=""
	json_cleanup
	json_load "$_res"
	_hosts="$(json_dump)"
	json_select "hosts"

	# If hosts came invalid
	if [ -z "$_hosts" ]
	then
		# Close the hosts json
		json_select ".."
		json_close_object
		json_cleanup
		return
	fi

	# Set defaults if does not exist or is not valid
	_max_hops="$(check_and_set_default_traceroute "$_max_hops" '1' '30' '15')"
	_nprobes="$(check_and_set_default_traceroute "$_nprobes" '1' '10' '3')"
	_trace_time=$(check_and_set_default_traceroute "$_trace_time" '1' '10' '3')

	# Loop through all hosts
	local _idx="1"
	while json_get_type type "$_idx" && [ "$type" = string ]
	do
		# The output json variable
		local _out_json=""

		# Get the address to traceroute
		# In the first iteration the hosts json is already opened
		# Every iteration, we get the route and close the json at the beginning
		# At the end of the loop, we reopen it to be used in the next iteration
		json_get_var _route "$((_idx++))"
		json_select ".."
		json_close_object
		json_cleanup

		local _traceroute="$(traceroute -I -n -m "$_max_hops" -q "$_nprobes" -w "$_trace_time" "$_route")"

		# Only process the traceroute if it is not empty
		if [ -n "$_traceroute" ]
		then
			# Get all hops, might find more than one per line
			local _hops="$(echo "$_traceroute" | grep -E -o '[0-9]*(\.[0-9]*){3}((  \*)*  [0-9]*\.[0-9]* ms)+')"

			# The ip of what the last hop should be
			local _last_ip="$(echo "$_traceroute" | grep -m 1 -Eo '[0-9]*(\.[0-9]*){3}')"
			
			# Find lines where there is more than 1 IP
			local _blacklist_hops="$(echo "$_traceroute" | grep -E -o '[0-9]*(\.[0-9]*){3}.*[0-9]*(\.[0-9]*){3}')"

			# The first IP of a line with more than 1 IP
			local _same_trie="$(echo "$_blacklist_hops" | awk '{print $1}')"
			local _repeated_hops=""

			# Break the blacklist lines into IP's, without the first IP
			_blacklist_hops="$(echo "$_blacklist_hops" | grep -E -o '  [0-9]*(\.[0-9]*){3}')"

			json_cleanup
			json_init

			# Check if any hop fail in all tries
			if [ -z "$(echo "$_traceroute" | grep -E -o '^( )*([0-9]+)(  \*){'$_nprobes'}')" ]
			then
				json_add_boolean all_hops_tested 1
			else
				json_add_boolean all_hops_tested 0
			fi

			# Check if the final ip was tested successfully
			if [ -n "$(echo "$_traceroute" | grep "$_last_ip  ")" ]
			then
				json_add_boolean reached_destination 1
			else
				json_add_boolean reached_destination 0
			fi

			# Add the route
			json_add_string address "$_route"

			# Add how many probes per hop
			json_add_int tries_per_hop $_nprobes

			# Add the array for hops
			json_add_array hops

			# Set the field separator to new line
			IFS=$'\n'

			for _hop_ip in $_same_trie
			do
				# Remove IPs that are duplicated or should be returned
				_blacklist_hops="$(echo "$_blacklist_hops" | grep -v "$_hop_ip")"

				# Hops with the same ip that must enter in the json
				_repeated_hops="${_repeated_hops}"$'\n'"$(echo "$_hops" | grep "$_hop_ip")"
			done

			for _hop in $_hops
			do
				# Get the ip of the hop
				local _ip="$(echo "$_hop" | awk '{print $1}')"

				# Check if ip is in _repeated_hops, add them, joining the time values
				local _hops_to_add="$(echo "$_repeated_hops" | grep "$_ip")"

				if [ -n "$_hops_to_add" ] && [ -z "$(echo "$_blacklist_hops" | grep "$_ip")" ]
				then
					create_time_object_traceroute "$_ip" "$_hops_to_add"

					# Add the ip to blacklist
					_blacklist_hops="${_blacklist_hops}"$'\n'"${_ip}"
				fi

				# Check if the ip is in _blacklist_hops, otherwise append to array
				if [ -z "$(echo "$_blacklist_hops" | grep "$_ip")" ]
				then
					create_time_object_traceroute "$_ip" "$_hop"
				fi
			done

			# Reset the field separator
			IFS=$' '

			json_close_array
			_out_json="$(json_dump)"
			json_close_object
		fi

		# Check if the json is empty, if so, just add the address
		if [ -z "$_out_json" ]
		then
			json_cleanup
			json_init

			# Add the route
			json_add_string address "$_route"
			_out_json="$(json_dump)"

			json_close_object
			json_cleanup
		fi

		# Send the json
		local _res=""
		local _processed="0"
		_res=$(send_data_flashman "traceroute" "$_out_json")

		# Check server response
		if [ -n "$_res" ]
		then
			json_cleanup
			json_load "$_res"
			json_get_var _processed processed
			json_close_object

			# If any error happenened, return
			if [ "$_processed" -lt 1 ]
			then
				return $_processed
			fi

		# In case of no response
		else
			return $_processed
		fi

		# Reopen the hosts json
		json_cleanup
		json_load "$_hosts"
		json_select "hosts"
	done

	# Final close the hosts json
	json_select ".."
	json_close_object
	json_cleanup

	return $_processed
}


# run_speed_ondemand_test
#	This function makes a speed test and send the result to flashman
#
# Inputs:
#	$1 - Server IP address
#		-- A valid IP tests against "http://$1/measure/file$i.bin",
#			where $i is the number of connections
#		-- An empty IP get the hosts from deviceinfo/get/speedtesthost
#	$2 - The username
#	$3 - How many connections
#	$4 - Timeout
#
# Outputs:
#	0 if could send data to flashman
#	1 if could not send data to flashman 
#	log in case an error happened
run_speed_ondemand_test() {
	local _sv_ip_addr="$1"
	local _username="$2"
	local _connections="$3"
	local _timeout="$4"

	# Default reply in case of failure
	local _reply='{"downSpeed":"","user":"'"$_username"'"}'

	# List to do the speedtests
	local _urllist=""
	local _retstatus

	# Check if server exists
	if [ -n "$_sv_ip_addr" ]
	then
		local _url="http://$_sv_ip_addr/measure"

		# Create array of urls
		for i in $(seq 1 "$_connections")
		do
			_urllist="$_urllist $_url/file$i.bin"
		done

	# Empty server means we must get from flashman
	else
		# Get the URL
		local _data="id=$(get_mac)"
		local _url_speedtest="deviceinfo/get/speedtesthost"
		local _host_response=$(rest_flashman "$_url_speedtest" "$_data")
		_retstatus=$?

		# Check if received the hosts
		if [ $_retstatus -eq 0 ]
		then
			local _succes=""
			
			json_cleanup
			json_load "$_host_response"
			json_get_var _success success

			# Check if success and get URL
			if [ "$_success" -eq 1 ]
			then
				local _url=""
				json_get_var _url host

				# Close Json
				json_close_object
				json_cleanup

				# Check if url is not empty
				if [ -n "$_url" ]
				then
					# Create array of urls
					for i in $(seq 1 "$_connections")
					do
						_urllist="$_urllist $_url"
					done
				
				# Invalid url
				else
					# Send an empty answer to flashman
					log "SPEEDTEST" "Empty speedtest url"

					send_data_flashman "speedtestresult" "$_reply"
					_retstatus=$?

					return $_retstatus
				fi
			
			# Otherwise, send an empty answer to flashman
			else
				# Close Json
				json_close_object
				json_cleanup

				log "SPEEDTESTRAW" "Speedtest host json with not success"

				send_data_flashman "speedtestresult" "$_reply"
				_retstatus=$?

				return $_retstatus
			fi

		# If could not get the hosts
		else
			# Send an empty answer to flashman
			log "SPEEDTESTRAW" "Could not get speedtest hosts"

			send_data_flashman "speedtestresult" "$_reply"
			_retstatus=$?

			return $_retstatus
		fi
	fi

	# Check if the url list is valid
	if [ -n "$_urllist" ]
	then
		local _result=""

		# Drop traffic
		log "SPEEDTEST" "Dropping traffic on firewall..."
		drop_all_forward_traffic

		# Do Speedtest
		_result="$(flash-measure "$_timeout" "$_connections" $_urllist)"
		_retstatus=$?

		# Restore traffic
		log "SPEEDTEST" "Restoring firewall to normal..."
		undrop_all_forward_traffic

		# Check if could make the speed test
		if [ "$_retstatus" -eq 0 ]
		then
			# If okay, send the result
			_reply='{"downSpeed":"'"$_result"'","user":"'"$_username"'"}'
		else
			# Otherwise send the default empty reply
			log "SPEEDTEST" "Could not make the speedtest: "$_result""
		fi

		# Send the data do flashman
		send_data_flashman "speedtestresult" "$_reply"
		_retstatus=$?

		return $_retstatus
	
	# If the url list is invalid
	else
		# Send an empty answer to flashman
		log "SPEEDTEST" "Invalid url list"

		send_data_flashman "speedtestresult" "$_reply"
		_retstatus=$?

		return $_retstatus
	fi

	return 1
}

run_diagnostics_test() {
	local _wan_status
	local _ipv4_status
	local _ipv6_status
	local _dns_status
	local _license_status
	local _result
	_wan_status="$(diagnose_wan_connectivity)"
	_ipv4_status="$(check_connectivity_ipv4)"
	_ipv6_status="$(check_connectivity_ipv6)"
	_dns_status="$(check_connectivity_internet)"
	_flashman_status="$(check_connectivity_flashman)"
	is_authenticated
	_license_status="$?"
	json_cleanup
	json_load "{}"
	json_add_string "wan" "$_wan_status"
	json_add_string "ipv4" "$_ipv4_status"
	json_add_string "ipv6" "$_ipv6_status"
	json_add_string "dns" "$_dns_status"
	json_add_string "license" "$_license_status"
	json_add_string "flashman" "$_flashman_status"
	echo "$(json_dump)"
	json_close_object
}

send_wps_status() {
	local _res
	local _processed
	local _wps_inform="$1"
	local _wps_content="$2"
	local _out_file="/tmp/wps_info.json"
	if [ "$_wps_inform" == "0" ]
	then
		_out_file="/tmp/wps_state.json"
	fi

	json_init
	json_add_string "wps_inform" "$_wps_inform"
	json_add_string "wps_content" "$_wps_content"
	json_dump > "$_out_file"
	json_cleanup

	if [ -f "$_out_file" ]
	then
		log "WPS" "Sending $_wps_inform and $_wps_content to Flashman..."

		local _file_content="$(cat "$_out_file")"
		_res=""
		_res=$(send_data_flashman "wps" "$_file_content")

		json_load "$_res"
		json_get_var _processed processed
		json_close_object

		return $_processed
	else
		log "WPS" "Status file not created"
		return 0
	fi
}

send_site_survey() {
	local _res
	local _device0
	local _device1
	local _INFO

	_device0=$(get_root_ifname 0)
	_device1=$(get_root_ifname 1)

	A="$(iwinfo $_device0 freqlist 2> /dev/null)"
	[ "$(is_5ghz_capable)" = "1" ] && \
		A=$A$'\n'"$(iwinfo $_device1 freqlist 2> /dev/null)"

	A=$A$'\n'"$(iwinfo $_device0 s 2> /dev/null)"
	[ "$(is_5ghz_capable)" = "1" ] && \
		A=$A$'\n'"$(iwinfo $_device1 s 2> /dev/null)"

	_INFO=$(echo "$A" | awk -e '
BEGIN {
  A=0;
} 

/GHz/ {
  if ($1 == "*")
    freq[$5+0]=$2;
  else
    freq[$4+0]=$1;
}

/Cell/ {
  A++;
  M[A]=$5
}

/Signal/ {
  S[A]=$2
}

/Mode/ {
  C[A]=freq[$4+0]
}

/ESSID/ {
  $1=""
  if ($0 == " unknown")
    ID[A]="\"Desconhecido\""
  else
    ID[A]=$0
}

END { 
  print "{ \"survey\": { "
  for (i=1; i<=A; i++) {
    if(i>1) print ","
    print "\""tolower(M[i])"\":"
    print "{ \"SSID\":"ID[i]","
    print " \"freq\":", C[i]*1000, ","
    print " \"signal\":", S[i]
    print "}"
  }
  print "} }"
}
	')

	_res=$(send_data_flashman "sitesurvey" "$_INFO")

	json_cleanup
	json_load "$_res"
	json_get_var _processed processed
	json_close_object

	return $_processed
}