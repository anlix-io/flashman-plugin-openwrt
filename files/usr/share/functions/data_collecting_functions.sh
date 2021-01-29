. /usr/share/libubox/jshn.sh
. /usr/share/functions/common_functions.sh
. /usr/share/functions/device_functions.sh
. /usr/share/flashman_init.conf

data_collecting_service() {
	log "DATA COLLECTING" "$1"
	case "$1" in
	start) is_data_colleting_license_available && /etc/init.d/data_collecting "$1";;
	restart) /etc/init.d/data_collecting stop; is_data_colleting_license_available && /etc/init.d/data_collecting start;;
	*) /etc/init.d/data_collecting "$1";;
	esac
}

data_collecting_is_running() {
	if [ -f /var/run/data_collecting.pid ]; then return 0; else return 1; fi
}

set_data_collecting_parameters() {
	local data_collecting_fqdn="$1" data_collecting_is_active="$2"
	
	local saved_data_collecting_fqdn
	json_cleanup
	json_load_file /root/flashbox_config.json
	json_get_var saved_data_collecting_fqdn data_collecting_fqdn

	# Updating value if $data_collecting_fqdn has changed.
	if [ "$saved_data_collecting_fqdn" != "$data_collecting_fqdn" ]; then
		log "DATA COLLECTING" "Updated data_collecting_fqdn parameter to $data_collecting_fqdn"
		json_add_string data_collecting_fqdn "$data_collecting_fqdn"
		json_dump > /root/flashbox_config.json # saving config json.
	fi

	json_close_object
	json_cleanup

	# "true" boolean value is translated as string "1" by jshn.sh
	# "false" boolean value is translated as string "0" by jshn.sh
	if [ "$data_collecting_is_active" = "1" ] && data_collecting_is_running; then
		# if data collecting is already running, no need to turn on.
		data_collecting_service start
	elif [ "$data_collecting_is_active" = "0" ] && ! data_collecting_is_running; then
		# if data collecting is already not running, no need to turn off.
		data_collecting_service stop
	fi
}

set_data_collecting_on_off() {
	if [ "$1" = "on" ]; then
		data_collecting_service start
	elif [ "$1" = "off" ]; then
		data_collecting_service stop
	fi
}

is_data_colleting_license_available() {
	local _is_available=1
	if [ "$FLM_USE_AUTH_SVADDR" == "y" ]; then
		local _res=$(curl -s \
			-A "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1)" \
			--tlsv1.2 --connect-timeout 5 --retry 1 \
			--data "mac=$(get_mac)&secret=$FLM_CLIENT_SECRET" \
			"https://$FLM_AUTH_SVADDR/api/device/license/data_collecting/is_available")
		if [ "$?" -eq 0 ]; then
			json_cleanup
			json_load "$_res" 2>/dev/null
			if [ "$?" == 0 ]; then
				json_get_var _is_available is_available
				json_close_object
				json_cleanup
			else
				log "DATA COLLECTING" "Invalid answer from controller when requesting data collecting license"
			fi
		else
			log "DATA COLLECTING" "Error connecting to controller ($_curl_res)"
		fi
	else
		_is_available=0
	fi
	return $_is_available
}

get_flashman_parameter() {
	local parameterName=$1

	local saved_value
	json_cleanup
	json_load_file /root/flashbox_config.json
	json_get_var saved_value "$parameterName"
	echo $saved_value
	json_close_object
	json_cleanup
}

set_collect_latencies() {
	local collect_latencies="$1"

	local saved_data_collecting_fqdn
	json_cleanup
	json_load_file /root/flashbox_config.json # opening json file.
	json_get_var saved_data_collecting_fqdn data_collecting_fqdn

	# Updating value if $collect_latencies has changed.
	if [ $saved_data_collecting_fqdn != $collect_latencies ]; then
		log "DATA COLLECTING" "Updated collect_latencies parameter to $collect_latencies"
		json_add_string collect_latencies "$collect_latencies"
		json_dump > /root/flashbox_config.json # saving config json.
	fi
	json_close_object
	json_cleanup
}