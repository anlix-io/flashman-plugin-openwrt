#!/bin/sh

. /usr/share/functions/api_functions.sh

WLAN_ITF="$1"
EVENT="$2"
INFO="$3"

# WPS event handlers
if [ "$EVENT" == "WPS-PBC-ACTIVE" ]
then
	# Push button active
	send_wps_status "0" "true"
elif [ "$EVENT" == "WPS-TIMEOUT" ] || [ "$EVENT" == "WPS-PBC-DISABLE" ]
then
	# Push button disabled
	send_wps_status "0" "false"
elif [ "$EVENT" == "WPS-SUCCESS" ]
then
	# Auth success
	send_wps_status "1" "true"
elif [ "$EVENT" == "WPS-REG-SUCCESS" ]
then
	# Device MAC authenticated by WPS
	send_wps_status "2" "$INFO"
fi
