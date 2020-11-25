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

# Bootstrap
reset_leds
blink_leds "0"
write_access_start_time 0

while true
do
	# We have layer 2 connectivity, now check external access
	if [ ! "$(check_connectivity_internet)" -eq 0 ]
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
