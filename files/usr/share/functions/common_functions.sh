#!/bin/sh

. /usr/share/flashman_init.conf
. /usr/share/libubox/jshn.sh
. /usr/share/functions/device_functions.sh

json_update_index() {
	_index=$1
	_json_var=$2

	json_init
	[ -f /etc/anlix_indexes ] && json_load_file /etc/anlix_indexes
	json_add_string "$_json_var" "$_index"
	json_close_object
	json_dump > /etc/anlix_indexes
}

get_indexes() {
	local _index=$1
	local _idx_val=""

	if [ -f /etc/anlix_indexes ]
	then
		json_cleanup
		json_load_file /etc/anlix_indexes
		json_get_var _idx_val "$_index"
		json_close_object
	fi
	echo "$_idx_val"
}

log() {
	logger -t "$1 " "$2"
}

#read a sequence of data into variables
get_data() {
	local d=0
	local _nuvals=$1
	shift
	local _prefix=$1
	shift
	while [ "$#" -gt 0 ]
	do
		eval "$_prefix$d=$1"
		d=$((d+1))
		shift
	done
	while [ "$d" -lt "$_nuvals" ]
	do
		eval "$_prefix$d=''"
		d=$((d+1))
	done
}

sh_timeout() {
	cmd="$1"
	timeout="$2"
	(
		eval "$cmd" &
		child=$!
		trap -- "" SIGTERM
		(
			sleep "$timeout"
			kill $child 2> /dev/null
		) &
		wait $child
	)
}

get_flashbox_version() {
	echo "$(cat /etc/anlix_version)"
}

get_flashbox_release() {
	echo "$FLM_RELID"
}

get_hardware_model() {
	if [ "$(type -t get_custom_hardware_model)" ]
	then
		get_custom_hardware_model
	else
		echo "$(cat /tmp/sysinfo/model | awk '{ print toupper($2) }')"
	fi
}

get_hardware_version() {
	if [ "$(type -t get_custom_hardware_version)" ]
	then
		get_custom_hardware_version
	else
		echo "$(cat /tmp/sysinfo/model | awk '{ print toupper($3) }')"
	fi
}

set_mqtt_secret() {
	json_cleanup
	json_load_file /root/flashbox_config.json
	json_get_var _mqtt_secret mqtt_secret
	json_close_object

	if [ "$_mqtt_secret" != "" ]
	then
		echo "$_mqtt_secret"
	else
		local _rand=$(head /dev/urandom | tr -dc A-Z-a-z-0-9)
		local _mqttsec=${_rand:0:32}
		local _data="id=$(get_mac)&mqttsecret=$_mqttsec"
		local _url="deviceinfo/mqtt/add"
		local _res=$(rest_flashman "$_url" "$_data")

		_retstatus=$?
		if [ $_retstatus -eq 0 ]
		then
			json_cleanup
			json_load "$_res"
			json_get_var _is_registered is_registered
			json_close_object

			if [ "$_is_registered" = "1" ]
			then
				json_cleanup
				json_load_file /root/flashbox_config.json
				json_add_string mqtt_secret $_mqttsec
				json_dump > /root/flashbox_config.json
				json_get_var _mqtt_secret mqtt_secret
				json_close_object
				echo "$_mqtt_secret"
			fi
		fi
	fi
}

reset_mqtt_secret() {
	json_cleanup
	json_load_file /root/flashbox_config.json
	json_get_var _mqtt_secret mqtt_secret

	if [ "$_mqtt_secret" != "" ]
	then
		json_add_string mqtt_secret ""
		json_dump > /root/flashbox_config.json
	fi

	json_close_object
	set_mqtt_secret
}

# send data to flashman using rest api
rest_flashman() {
	local _url=$1
	local _data=$2
	local _res
	local _curl_out
	_res=$(curl -s \
				-A "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1)" \
				--tlsv1.2 --connect-timeout 5 --retry 1 \
				--data "$_data&secret=$FLM_CLIENT_SECRET" \
				"https://$FLM_SVADDR/$_url")
	_curl_out=$?

	if [ "$_curl_out" -eq 0 ]
	then
		echo "$_res"
		return 0
	elif [ "$_curl_out" -eq 51 ]
	then
		# curl code 51 is bad certificate
		return 2
	else
		log "REST FLASHMAN" "Error connecting to server ($_curl_out)"
		# other curl errors
		return 1
	fi
}

is_authenticated() {
	local _res
	local _is_authenticated=1
	local _tmp_auth_file="/tmp/last_authentication"
	local _tmp_file_valid=0

	# Get the date: seconds since 1970-01-01 00:00:00 UTC
	local _date="$(date '+%s')"

	# Check if _tmp_auth_file exists and check FLM_REAUTH_TIME if is more than
	# 30 minutes and less than 8 hours (480 minutes)
	if [ -f "$_tmp_auth_file" ] && [ "$FLM_REAUTH_TIME" -ge "30" ] &&
		[ "$FLM_REAUTH_TIME" -le "480" ]
	then
		local _file_date=$(cat $_tmp_auth_file)

		# 60*Minute + Seconds; Add the constant to the file
		local _file_seconds="$(echo $_file_date | awk '{print 60*'$FLM_REAUTH_TIME'+$1}')"

		# Check the date
		if [ "$_date" -le "$_file_minute" ]
		then
			# Authenticated
			_is_authenticated=0
			log "AUTHENTICATOR" "Authenticated by cache, with date: $_file_date"

			return $_is_authenticated
		else
			# Remove the file
			rm $_tmp_auth_file

			log "AUTHENTICATOR" "Removed authentication cache with date: $_file_date"
		fi

	fi

	if [ "$FLM_USE_AUTH_SVADDR" == "y" ]
	then
		#
		# WARNING! No spaces or tabs inside the following string!
		#
		local _data
		_data="id=$(get_mac)&\
organization=$FLM_CLIENT_ORG&\
secret=$FLM_CLIENT_SECRET&\
model=$(get_hardware_model)&\
model_ver=$(get_hardware_version)&\
firmware_ver=$(get_flashbox_version)"

		_res=$(curl -s \
			-A "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1)" \
			--tlsv1.2 --connect-timeout 5 --retry 1 \
			--data "$_data" \
			"https://$FLM_AUTH_SVADDR/api/device/auth")

		local _curl_res=$?
		if [ $_curl_res -eq 0 ]
		then
			json_cleanup
			json_load "$_res" 2>/dev/null
			if [ $? == 0 ]
			then
				json_get_var _is_authenticated is_authenticated
				json_close_object

				# If is_authenticated is 0 (Authenticated) than create a cache
				if [ "$_is_authenticated" -eq 0 ]
				then
					# Save the date
					echo "$_date" > $_tmp_auth_file

					log "AUTHENTICATOR" "Creating authentication cache"
				fi

			else
				log "AUTHENTICATOR" "Invalid answer from controler"
			fi
		else
			log "AUTHENTICATOR" "Error connecting to controler ($_curl_res)"
		fi
	else
		_is_authenticated=0
	fi

	# If not authenticated and the _tmp_auth_file file exists, delete it
	if [ "$_is_authenticated" -eq 1 ] && [ -f "$_tmp_auth_file" ]
	then
		rm $_tmp_auth_file

		log "AUTHENTICATOR" "Removed authentication cache due to not being authenticated"
	fi

	return $_is_authenticated
}