. /usr/share/libubox/jshn.sh
. /usr/share/flashman_init.conf

# saves data collecting parameters if they have changed, saves file only if at least one parameter has changed
# and starts the data collecting service, if not already running, or stops it if it's running, according to 
# 'saved_data_collecting_is_active' parameter.
set_data_collecting_parameters() {
	local data_collecting_is_active="${1:-0}"
	local data_collecting_has_latency="${2:-0}"
	local data_collecting_alarm_fqdn="${3:-$FLM_SVADDR}"
	local data_collecting_ping_fqdn="${4:-$FLM_SVADDR}"
	local data_collecting_ping_packets="${5:-100}"

	json_cleanup
	json_load_file /root/flashbox_config.json
	json_get_var saved_data_collecting_is_active data_collecting_is_active
	json_get_var saved_data_collecting_has_latency data_collecting_has_latency
	json_get_var saved_data_collecting_alarm_fqdn data_collecting_alarm_fqdn
	json_get_var saved_data_collecting_ping_fqdn data_collecting_ping_fqdn
	json_get_var saved_data_collecting_ping_packets data_collecting_ping_packets

	local anyChange=false

	# Updating value if $data_collecting_is_active has changed.
	if [ "$saved_data_collecting_is_active" != "$data_collecting_is_active" ]; then
		anyChange=true
		json_add_boolean data_collecting_is_active "$data_collecting_is_active"
		log "DATA_COLLECTING" "Updated 'data_collecting_is_active' parameter to '$data_collecting_is_active'"
	fi

	# Updating value if $data_collecting_has_latency has changed.
	if [ "$saved_data_collecting_has_latency" != "$data_collecting_has_latency" ]; then
		anyChange=true
		json_add_boolean data_collecting_has_latency "$data_collecting_has_latency"
		log "DATA_COLLECTING" "Updated 'data_collecting_has_latency' parameter to '$data_collecting_has_latency'"
	fi

	# Updating value if $data_collecting_alarm_fqdn has changed.
	if [ "$saved_data_collecting_alarm_fqdn" != "$data_collecting_alarm_fqdn" ]; then
		anyChange=true
		json_add_string data_collecting_alarm_fqdn "$data_collecting_alarm_fqdn"
		log "DATA_COLLECTING" "Updated 'data_collecting_alarm_fqdn' parameter to '$data_collecting_alarm_fqdn'"
	fi

	# Updating value if $data_collecting_ping_fqdn has changed.
	if [ "$saved_data_collecting_ping_fqdn" != "$data_collecting_ping_fqdn" ]; then
		anyChange=true
		json_add_string data_collecting_ping_fqdn "$data_collecting_ping_fqdn"
		log "DATA_COLLECTING" "Updated 'data_collecting_ping_fqdn' parameter to '$data_collecting_ping_fqdn'"
	fi

	# Updating value if $data_collecting_alarm_fqdn has changed.
	if [ "$saved_data_collecting_ping_packets" != "$data_collecting_ping_packets" ]; then
		anyChange=true
		json_add_int data_collecting_ping_packets "$data_collecting_ping_packets"
		log "DATA_COLLECTING" "Updated 'data_collecting_ping_packets' parameter to '$data_collecting_ping_packets'"
	fi

	# saving config json if any parameter has changed.
	"$anyChange" && json_dump > /root/flashbox_config.json;
	json_close_object
	json_cleanup


	# "true" boolean value is translated as string "1" by jshn.sh
	# "false" boolean value is translated as string "0" by jshn.sh
	if [ "$data_collecting_is_active" = "1" ] && [ "$data_collecting_ping_fqdn" != "" ]; then
		# reload won't restart data collecting service if it's already running.
		/etc/init.d/data_collecting reload
	elif [ "$data_collecting_is_active" != "1" ]; then
		/etc/init.d/data_collecting stop 2>/dev/null
	fi
}
