#!/bin/sh

. /usr/share/flashman_init.conf
. /usr/share/libubox/jshn.sh
. /usr/share/functions/common_functions.sh
. /usr/share/functions/system_functions.sh
. /usr/share/functions/device_functions.sh
. /usr/share/functions/wireless_functions.sh
. /usr/share/functions/network_functions.sh
. /usr/share/functions/api_functions.sh

_need_update=0
_force_update=0
_cert_error=0
while true
do
	sleep 300

	_rand=$(head /dev/urandom | tr -dc "012345")
	_number=${_rand:0:1}

	if [ "$_number" -eq 3 ] || [ "$1" == "now" ]
	then
		# Get WiFi data
		json_cleanup
		json_load "$(get_wifi_local_config)"
		json_get_var _local_ssid_24 local_ssid_24
		json_get_var _local_password_24 local_password_24
		json_get_var _local_channel_24 local_channel_24
		json_get_var _local_hwmode_24 local_hwmode_24
		json_get_var _local_htmode_24 local_htmode_24
		json_get_var _local_state_24 local_state_24
		json_get_var _local_5ghz_capable local_5ghz_capable
		json_get_var _local_ssid_50 local_ssid_50
		json_get_var _local_password_50 local_password_50
		json_get_var _local_channel_50 local_channel_50
		json_get_var _local_hwmode_50 local_hwmode_50
		json_get_var _local_htmode_50 local_htmode_50
		json_get_var _local_state_50 local_state_50
		json_close_object

		log "KEEPALIVE" "Ping Flashman ..."
		#
		# WARNING! No spaces or tabs inside the following string!
		#
		_data="id=$(get_mac)&\
flm_updater=0&\
version=$(get_flashbox_version)&\
model=$(get_hardware_model)&\
model_ver=$(get_hardware_version)&\
release_id=$FLM_RELID&\
pppoe_user=$(uci -q get network.wan.username)&\
pppoe_password=$(uci -q get network.wan.password)&\
wan_ip=$(get_wan_ip)&\
wan_negociated_speed=$(get_wan_negotiated_speed)&\
wan_negociated_duplex=$(get_wan_negotiated_duplex)&\
lan_addr=$(get_lan_ipaddr)&\
lan_netmask=$(get_lan_netmask)&\
wifi_ssid=$_local_ssid_24&\
wifi_password=$_local_password_24&\
wifi_channel=$_local_channel_24&\
wifi_band=$_local_htmode_24&\
wifi_mode=$_local_hwmode_24&\
wifi_state=$_local_state_24&\
wifi_5ghz_capable=$_local_5ghz_capable&\
wifi_ssid_5ghz=$_local_ssid_50&\
wifi_password_5ghz=$_local_password_50&\
wifi_channel_5ghz=$_local_channel_50&\
wifi_band_5ghz=$_local_htmode_50&\
wifi_mode_5ghz=$_local_hwmode_50&\
wifi_state_5ghz=$_local_state_50&\
connection_type=$(get_wan_type)&\
ntp=$(ntp_anlix)&\
sysuptime=$(sys_uptime)&\
wanuptime=$(wan_uptime)"
		_url="deviceinfo/syn/"
		_res=$(rest_flashman "$_url" "$_data")

		_retstatus=$?
		if [ $_retstatus -eq 0 ]
		then
			_cert_error=0
			json_cleanup
			json_load "$_res"
			json_get_var _do_update do_update
			json_get_var _do_newprobe do_newprobe
			json_get_var _mqtt_status mqtt_status
			json_close_object

			if [ "$_do_newprobe" = "1" ]
			then
				log "KEEPALIVE" "Router Registred in Flashman Successfully!"
				# On a new probe, force a new registry in mqtt secret
				reset_mqtt_secret > /dev/null
				sh /usr/share/flashman_update.sh
			fi

			if [ "$_do_update" = "1" ]
			then
				_need_update=$(( _need_update + 1 ))
			else
				_need_update=0
			fi

			if [ $_need_update -gt 7 ]
			then
				if [ $_force_update -eq 1 ] 
				then
					_force_update=0
				else
					lock -n /tmp/lock_firmware || _force_update=1
				fi

				if [ $_force_update -eq 0 ]
				then
					lock -u /tmp/lock_firmware
					# More than 7 checks (>20 min), force a firmware update
					log "KEEPALIVE" "Running update ..."
					sh /usr/share/flashman_update.sh
				fi
				_need_update=0
			fi

			if [ "$_mqtt_status" = "0" ]
			then
				# Check is mqtt is running
				mqttpid=$(pgrep anlix-mqtt)
				if [ "$mqttpid" ] && [ $mqttpid -gt 0 ]
				then
					log "KEEPALIVE" "MQTT not connected to Flashman! Restarting..."
					kill -9 $mqttpid
				fi
			fi
		elif [ $_retstatus -eq 2 ]
		then
			log "KEEPALIVE" "Fail in Flashman Certificate! Retry $_cert_error"
			# Certificate problems are related to desync dates
			# Wait NTP, or correct if we can...
			_cert_error=$(( _cert_error + 1 ))
			if [ $_cert_error -gt 7 ]
			then
				# More than 7 checks (>20 min), force a date update
				log "KEEPALIVE" "Try resync date with Flashman!"
				resync_ntp
				_cert_error=0
			fi
		else
			log "KEEPALIVE" "Fail in Rest Flashman! Aborting..."
		fi

		[ "$(type -t anlix_force_clean_memory)" ] && anlix_force_clean_memory
	fi
done
