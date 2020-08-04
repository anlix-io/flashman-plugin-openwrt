. /usr/share/libubox/jshn.sh
. /usr/share/functions/common_functions.sh

measuresService() {
	/etc/init.d/data_collecting "$1"
}

set_data_collecting_params() {
	local data_collecting_fqdn="$1" data_collecting_is_active="$2"
	
	local saved_data_collecting_fqdn
	local saved_data_collecting_is_active
	json_cleanup
	json_load_file /root/flashbox_config.json
	json_get_var saved_data_collecting_fqdn data_collecting_fqdn
	json_get_var saved_data_collecting_is_active data_collecting_is_active

	local _changed_params=0
	# Check if data_collecting_fqdn is different.
	if [ "saved_data_collecting_fqdn" != "$data_collecting_fqdn" ]
	then
		log "MEASURES" "Updating data_collecting_fqdn parameter"
		json_add_string data_collecting_fqdn "$data_collecting_fqdn"
		_changed_params=1
	fi

	# $data_collecting_is_active comes from flashman as 0 or 1 but we save it as "y" or "n".
	# we check if $data_collecting_is_active has changed (it's a "y" but we received 0 or it's an "n" and we received a 1)
	if [ "data_collecting_is_active" != "1" ] || [ "$data_collecting_fqdn" = "" ]
	then
		# Properly kill measures service
		log "MEASURES" "Stopping measures service"
		measuresService stop
		measuresService disable
		json_add_string data_collecting_is_active "n"
	elif [ "data_collecting_is_active" = "1" ] && { [ "$saved_data_collecting_is_active" != "y" ] || [ "$_changed_params" = "1" ]; }
	then
		# Properly restart measures service if it was active and anything changed
		# or if it was inactive and new values are valid.
		if [ "$data_collecting_fqdn" != "" ]
		then
			log "MEASURES" "Restarting measures service"
			json_add_string data_collecting_is_active "y"
			# measuresService restart
			measuresService stop; measuresService start
		fi
	fi

	json_dump > /root/flashbox_config.json
	json_close_object
}

set_data_collecting_on_off() {
	if [ "$1" = "on" ]; then
		log "MEASURES" "Starting measures service"
		measuresService enable
		measuresService start
	elif [ "$1" = "off" ]; then
		log "MEASURES" "Stopping measures service"
		measuresService stop
		measuresService disable
	fi
}