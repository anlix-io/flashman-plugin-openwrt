. /usr/share/libubox/jshn.sh
. /usr/share/functions/common_functions.sh

data_collecting_service() {
	/etc/init.d/data_collecting "$1"
}

set_data_collecting_parameters() {
	local data_collecting_fqdn="$1" data_collecting_is_active="$2"
	
	local saved_data_collecting_fqdn saved_data_collecting_is_active
	json_cleanup
	json_load_file /root/flashbox_config.json
	json_get_var saved_data_collecting_fqdn data_collecting_fqdn
	json_get_var saved_data_collecting_is_active data_collecting_is_active

	# Check if $data_collecting_fqdn has changed.
	if [ "$saved_data_collecting_fqdn" != "$data_collecting_fqdn" ]; then
		log "DATA COLLECTING" "Updating data_collecting_fqdn parameter"
		json_add_string data_collecting_fqdn "$data_collecting_fqdn"
	fi

	# Check if $data_collecting_is_active has changed.
	if [ "$saved_data_collecting_is_active" != "$data_collecting_is_active" ]; then
		log "DATA COLLECTING" "Updating data_collecting_is_active parameter"
		json_add_string data_collecting_is_active "$data_collecting_is_active"
	fi

	json_dump > /root/flashbox_config.json
	json_close_object

	# "true" boolean value is translated as string "1" by jshn.sh
	# "false" boolean value is translated as string "0" by jshn.sh
	if [ "$data_collecting_is_active" = "1" ]; then
		log "DATA COLLECTING" "Starting data collecting service"
		data_collecting_service start
	else
		# this case happens if device loses connection and later reconnects, without 
		# rebooting, and $data_collecting_is_active has changed to false in flashman during that time.
		log "DATA COLLECTING" "Stopping data collecting service"
		data_collecting_service stop
	fi	
}

set_data_collecting_on_off() {
	# jshn translates false values to string "0". to simplify our lives, 
	# we write string "0" when we mean boolean false.
	local is_active="0" 

	if [ "$1" = "on" ]; then
		log "DATA COLLECTING" "Starting data collecting service"
		data_collecting_service start
		# jshn translates true boolean values to string "1", to simplify our 
		# lives, we write string "1" when we mean boolean true.
		is_active="1"
	elif [ "$1" = "off" ]; then
		log "DATA COLLECTING" "Stopping data collecting service"
		data_collecting_service stop
	fi

	json_cleanup
	json_load_file /root/flashbox_config.json
	json_add_string data_collecting_is_active "$is_active"
	json_dump > /root/flashbox_config.json
	json_close_object
}