. /usr/share/libubox/jshn.sh
. /usr/share/functions/common_functions.sh

measuresService() {
	/etc/init.d/collect_data "$1"
}

set_measures_params() {
	local measures_fqdn="$1" measures_is_active="$2"
	
	local saved_measures_fqdn
	local saved_measures_is_active
	json_cleanup
	json_load_file /root/flashbox_config.json
	json_get_var saved_measures_fqdn measures_fqdn
	json_get_var saved_measures_is_active measures_is_active

	local _changed_params=0
	# Check if measures_fqdn is different.
	if [ "saved_measures_fqdn" != "$measures_fqdn" ]
	then
		log "MEASURES" "Updating measures_fqdn parameter"
		json_add_string measures_fqdn "$measures_fqdn"
		_changed_params=1
	fi

	# $measures_is_active comes from flashman as 0 or 1 but we sabe it as "y" or "n".
	# we check if $measures_is_active has changed (it's a "y" but we received 0 or it's a "n" and we received a 1)
	if [ "measures_is_active" != "1" ] || [ "$measures_fqdn" = "" ]
	then
		# Properly kill measures service
		log "MEASURES" "Stopping measures service"
		measuresService stop
		measuresService disable
		json_add_string measures_is_active "n"
	elif [ "measures_is_active" = "1" ] && { [ "$saved_measures_is_active" != "y" ] || [ "$_changed_params" = "1" ]; }
	then
		# Properly restart measures service if was active and anything changed
		# or if it was inactive and new values are valid.
		if [ "$measures_fqdn" != "" ]
		then
			log "MEASURES" "Restarting measures service"
			json_add_string measures_is_active "y"
			measuresService restart
			# measuresService stop; measuresService start
		fi
	fi

	json_dump > /root/flashbox_config.json
	json_close_object
}

set_measures_on_off() {
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