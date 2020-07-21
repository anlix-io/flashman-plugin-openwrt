. /usr/share/libubox/jshn.sh

measureService() {
	/etc/init.d/collect_data "$1"
}

set_measure_params() {
	local measure_fqdn="$1" measure_is_active="$2"
	
	local saved_fqdn
	local saved_is_active
	json_cleanup
	json_load_file /root/flashbox_config.json
	json_get_var saved_fqdn measure_fqdn
	json_get_var saved_is_active measure_is_active

	local _changed_params=0
	# Check if measure_fqdn is different.
	if [ "saved_fqdn" != "$measure_fqdn" ]
	then
		log "MEASURE" "Updating measure_fqdn parameter"
		json_add_string measure_fqdn "$measure_fqdn"
		_changed_params=1
	fi

	# $measure_is_active comes from flashman as 0 or 1 but we sabe it as "y" or "n".
	# we check if $measure_is_active has changed (it's a "y" but we received 0 or it's a "n" and we received a 1)
	if [ "measure_is_active" != "1" ] || [ "$measure_fqdn" = "" ]
	then
		# Properly kill measure service
		log "MEASURE" "Stopping measure service"
		measureService stop
		measureService disable
		json_add_string measure_is_active "n"
	elif [ "measure_is_active" = "1" ] && { [ "$saved_is_active" != "y" ] || [ "$_changed_params" = "1" ]; }
	then
		# Properly restart measure service if was active and anything changed
		# or if it was inactive and new values are valid.
		if [ "$measure_fqdn" != "" ]
		then
			log "MEASURE" "Restarting measure service"
			json_add_string measure_is_active "y"
			measureService restart
			measureService stop; measureService start
		fi
	fi

	json_dump > /root/flashbox_config.json
	json_close_object
}

set_measure_on_off() {
	if [ "$1" = "on" ]; then
		log "MEASURE" "Starting measure service"
		measureService enable
		measureService start
	elif [ "$1" = "off" ]; then
		log "MEASURE" "Stopping measure service"
		measureService stop
		measureService disable
	fi
}