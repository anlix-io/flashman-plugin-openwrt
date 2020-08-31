#!/bin/sh

WLAN_ITF="$1"
EVENT="$2"
INFO="$3"

# WPS event handlers
if [ "$EVENT" == "WPS-PBC-ACTIVE" ]
then
	# Push button active
	logger -t $0 "Push button active"
elif [ "$EVENT" == "WPS-TIMEOUT" ] || [ "$EVENT" == "WPS-PBC-DISABLE" ]
then
	# Push button disabled
	logger -t $0 "Push button disabled"
elif [ "$EVENT" == "WPS-SUCCESS" ]
then
	# Auth success
	logger -t $0 "WPS auth successfull"
elif [ "$EVENT" == "WPS-REG-SUCCESS" ]
then
	# Device MAC authenticated by WPS
	logger -t $0 "Device connected $INFO"
fi
