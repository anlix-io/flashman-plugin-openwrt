#!/bin/sh

. /usr/share/flashman_init.conf
. /usr/share/libubox/jshn.sh
. /usr/share/functions/common_functions.sh

# Verify ntp
ntp_anlix() {
	if [ -f /tmp/anlixntp ]
	then
		cat /tmp/anlixntp
	else
		echo "unsync"
	fi
}

resync_ntp() {
	local _curdate=$(date +%s)
	local _data="id=$(get_mac)&ntp=$(ntp_anlix)&date=$_curdate"
	local _url="https://$FLM_SVADDR/deviceinfo/ntp"

	# Date sync with Flashman is done insecurely
	local _res
	local _retstatus
	_res=$(curl -k -s \
				-A "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1)" \
				--tlsv1.2 --connect-timeout 5 --retry 1 --data "$_data" \
				"$_url")
	_retstatus=$?
	if [ $_retstatus -eq 0 ]
	then
		json_cleanup
		json_load "$_res"
		json_get_var _need_update need_update
		json_get_var _new_date new_date
		json_close_object

		if [ "$_need_update" = "1" ]
		then
			log "NTP_FLASHMAN" "Change date to $_new_date"
			date "@$_new_date" > /dev/null
			echo "flash_sync" > /tmp/anlixntp
		else
			log "NTP_FLASHMAN" "No need to change date (Server clock $_new_date)"
			echo "flash_sync" > /tmp/anlixntp
		fi
	else
		log "NTP_FLASHMAN" "Error in CURL: $_retstatus"
	fi
}
