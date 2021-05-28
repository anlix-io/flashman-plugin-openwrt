#!/bin/sh

. /usr/share/functions/api_functions.sh

WLAN_ITF="$1"
EVENT="$2"
INFO="$3"

# WPS event handlers
if [ "$EVENT" == "WPS-PBC-ACTIVE" ]
then
	# Push button active
	send_wps_status "0" "1"
	if [ "$WLAN_ITF" == "ra0" ]
	then
		sleep 120 # Wait 2 minutes
		send_wps_status "0" "0"
	fi
elif [ "$EVENT" == "WPS-TIMEOUT" ] || [ "$EVENT" == "WPS-PBC-DISABLE" ]
then
	# Push button disabled
	send_wps_status "0" "0"
	# State 1 should be "$EVENT" == "WPS-SUCCESS" but useless at the moment
elif [ "$EVENT" == "WPS-REG-SUCCESS" ]
then
	# Device MAC authenticated by WPS
	send_wps_status "2" "$INFO"
fi
