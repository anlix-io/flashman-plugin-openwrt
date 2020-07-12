#!/bin/sh

. /usr/share/functions/common_functions.sh
. /usr/share/functions/device_functions.sh
. /usr/share/functions/api_functions.sh

DO_RESTART=1

check_connectivity_internet() {
	_addrs="www.google.com.br"$'\n'"www.facebook.com"$'\n'"www.globo.com"
	for _addr in $_addrs
	do
		if ping -q -c 1 -w 4 "$_addr"  > /dev/null 2>&1
		then
			# true
			echo 0
			return
		fi
	done
	# No successfull pings

	# false
	echo 1
	return
}

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

reset_leds
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
