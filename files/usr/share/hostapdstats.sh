#!/bin/sh

. /usr/share/flashman_init.conf
. /usr/share/libubox/jshn.sh
. /usr/share/functions/device_functions.sh

WLAN_ITF="$1"
EVENT="$2"
INFO="$3"

# WPS event handlers
if [ "$EVENT" == "WPS-PBC-ACTIVE" ]
then
	# Push button active
	logger -t $0 "Push button active"

	local _out_file="/tmp/wps_status.json"

	json_init
	json_add_string "wpsinform" "0"
	json_add_string "wpscontent" "true"
	json_dump > "$_out_file"
	json_cleanup

	if [ -f "$_out_file" ]
	then
		# Ignore response since there is no countermeasure
		cat "$_out_file" | curl -s --tlsv1.2 --connect-timeout 5 \
			--retry 1 -H "Content-Type: application/json" \
			-H "X-ANLIX-ID: $(get_mac)" -H "X-ANLIX-SEC: $FLM_CLIENT_SECRET" \
			--data @- "https://$FLM_SVADDR/deviceinfo/receive/wps"
	fi

elif [ "$EVENT" == "WPS-TIMEOUT" ] || [ "$EVENT" == "WPS-PBC-DISABLE" ]
then
	# Push button disabled
	logger -t $0 "Push button disabled"

	local _out_file="/tmp/wps_status.json"

	json_init
	json_add_string "wpsinform" "0"
	json_add_string "wpscontent" "false"
	json_dump > "$_out_file"
	json_cleanup

	if [ -f "$_out_file" ]
	then
		# Ignore response since there is no countermeasure
		cat "$_out_file" | curl -s --tlsv1.2 --connect-timeout 5 \
			--retry 1 -H "Content-Type: application/json" \
			-H "X-ANLIX-ID: $(get_mac)" -H "X-ANLIX-SEC: $FLM_CLIENT_SECRET" \
			--data @- "https://$FLM_SVADDR/deviceinfo/receive/wps"
	fi

elif [ "$EVENT" == "WPS-SUCCESS" ]
then
	# Auth success
	logger -t $0 "WPS auth successfull"

	local _out_file="/tmp/wps_status.json"

	json_init
	json_add_string "wpsinform" "1"
	json_add_string "wpscontent" "true"
	json_dump > "$_out_file"
	json_cleanup

	if [ -f "$_out_file" ]
	then
		# Ignore response since there is no countermeasure
		cat "$_out_file" | curl -s --tlsv1.2 --connect-timeout 5 \
			--retry 1 -H "Content-Type: application/json" \
			-H "X-ANLIX-ID: $(get_mac)" -H "X-ANLIX-SEC: $FLM_CLIENT_SECRET" \
			--data @- "https://$FLM_SVADDR/deviceinfo/receive/wps"
	fi

elif [ "$EVENT" == "WPS-REG-SUCCESS" ]
then
	# Device MAC authenticated by WPS
	logger -t $0 "Device connected $INFO"

	local _out_file="/tmp/wps_status.json"

	json_init
	json_add_string "wpsinform" "2"
	json_add_string "wpscontent" "$INFO"
	json_dump > "$_out_file"
	json_cleanup

	if [ -f "$_out_file" ]
	then
		# Ignore response since there is no countermeasure
		cat "$_out_file" | curl -s --tlsv1.2 --connect-timeout 5 \
			--retry 1 -H "Content-Type: application/json" \
			-H "X-ANLIX-ID: $(get_mac)" -H "X-ANLIX-SEC: $FLM_CLIENT_SECRET" \
			--data @- "https://$FLM_SVADDR/deviceinfo/receive/wps"
	fi
fi
