#!/bin/sh

. /usr/share/functions/common_functions.sh
. /usr/share/functions/device_functions.sh
. /usr/share/functions/network_functions.sh
. /usr/share/functions/api_functions.sh

DO_RESTART=1

write_access_start_time() {
	local _start_time="$1"
	# Reset external access start time
	json_init
	if [ -f /tmp/ext_access_time.json ]
	then
		json_load_file /tmp/ext_access_time.json
	fi
	json_add_string "starttime" "$_start_time"
	json_dump > "/tmp/ext_access_time.json"
	json_cleanup
}

# opens 'flashbox_config.json' and reads the connectivity pings boolean.
read_data_collecting_parameters() {
	json_cleanup
	json_load_file "/root/flashbox_config.json"
	# non-existing value is translated to empty string.
	# reading to global variable.
	json_get_var data_collecting_conn_pings data_collecting_conn_pings
	json_get_var data_collecting_is_active data_collecting_is_active
	json_close_object

	# we collect connectivity pings if both conn_pings and is_active is enabled.
	[ "$data_collecting_is_active" -eq 1 ] && \
		[ "$data_collecting_conn_pings" -eq 1 ] && collect_pings=1
}
collect_pings=0

# Bootstrap
reset_leds
blink_leds "0"
write_access_start_time 0
read_data_collecting_parameters

while true
do
	# We have layer 2 connectivity, now check external access
	if [ ! "$(check_connectivity_internet '' $collect_pings)" -eq 0 ]
	then
		# No external access
		log "CHECK_WAN" "No external access..."
		blink_leds "$DO_RESTART"
		DO_RESTART=1
		write_access_start_time 0
	else
		# The device has external access. Cancel notifications
		if [ $DO_RESTART -ne 0 ]
		then
			log "CHECK_WAN" "External access restored..."
			reset_leds
			DO_RESTART=0
			# Reset external access start time
			write_access_start_time "$(sys_uptime)"
		fi
	fi
	sleep 2
done
