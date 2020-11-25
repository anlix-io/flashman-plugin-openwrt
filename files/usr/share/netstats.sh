#!/bin/sh

. /usr/share/functions/device_functions.sh
. /usr/share/functions/network_functions.sh

SLEEP_TIME=60
[ "$(type -t anlix_force_clean_memory)" ] && SLEEP_TIME=300

while true
do
	# Collect and store wan traffic information
	store_wan_bytes
	[ "$(type -t anlix_force_clean_memory)" ] && anlix_force_clean_memory
	sleep $SLEEP_TIME
done
