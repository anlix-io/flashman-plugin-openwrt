. /usr/share/libubox/jshn.sh
. /usr/share/functions/common_functions.sh

data_collecting_service() {
	/etc/init.d/data_collecting "$1"
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

	local changed_parameters=0
	# Check if $data_collecting_fqdn has changed.
	if [ "$saved_data_collecting_fqdn" != "$data_collecting_fqdn" ]; then
		changed_parameters=1
		log "DATA COLLECTING" "Updating data_collecting_fqdn parameter"
		json_add_string data_collecting_fqdn "$data_collecting_fqdn"
	fi

	# save config json.
	json_dump > /root/flashbox_config.json
	json_close_object

	# "true" boolean value is translated as string "1" by jshn.sh
	# "false" boolean value is translated as string "0" by jshn.sh
	if [ "$data_collecting_is_active" = "1" ]; then
		if data_collecting_is_running; then
			if [ "$changed_parameters" = 1 ]; then
				# this case happens if device loses connection and later reconnects, without 
				# rebooting, and $data_collecting_fqdn has changed in flashman during that time.
				log "DATA COLLECTING" "Restarting data collecting service"
				data_collecting_service restart;
			fi
		else
			log "DATA COLLECTING" "Starting data collecting service"
			data_collecting_service start
		fi
	else
		# this case happens if device loses connection and later reconnects, without 
		# rebooting, and $data_collecting_is_active has changed to false in flashman during that time.
		log "DATA COLLECTING" "Stopping data collecting service"
		data_collecting_service stop
	fi	
}

set_data_collecting_on_off() {
	if [ "$1" = "on" ]; then
		log "DATA COLLECTING" "Starting data collecting service"
		data_collecting_service start
	elif [ "$1" = "off" ]; then
		log "DATA COLLECTING" "Stopping data collecting service"
		data_collecting_service stop
	fi
}