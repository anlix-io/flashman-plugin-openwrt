#!/bin/sh

. /usr/share/libubox/jshn.sh
. /usr/share/functions/common_functions.sh
. /usr/share/functions/device_functions.sh
. /usr/share/functions/network_functions.sh

get_hwmode_24() {
	local _htmode_24="$(uci -q get wireless.radio0.htmode)"
	[ "$_htmode_24" = "NOHT" ] && echo "11g" || echo "11n"
}

get_htmode_24() {
	local _htmode_24="$(uci -q get wireless.radio0.htmode)"
	local _noscan_24="$(uci -q get wireless.radio0.noscan)"
	if [ "$_noscan_24" == "0" ]
	then
		[ "$_htmode_24" = "HT40" ] && echo "auto" || echo "HT20"
	else
		[ "$_htmode_24" = "HT40" ] && echo "HT40" || echo "HT20"
	fi
}

get_htmode_50() {
	local _htmode_50="$(uci -q get wireless.radio1.htmode)"
	local _noscan_50="$(uci -q get wireless.radio1.noscan)"
	[ "$_noscan_50" == "0" ] && echo "auto" || echo "$_htmode_50"
}

get_wifi_state() {
	local _q=$(uci -q get wireless.default_radio$1.disabled)
	[ "$_q" ] && [ "$_q" = "1" ] && echo "0" || echo "1"
}

auto_channel_selection() {
	local _iface=$1
	case "$_iface" in
		wlan0)
			echo "6"
		;;
		wlan1)
			echo "40"
		;;
	esac
}

change_wps_state() {
	local _radio="$1"
	local _enabled="$2"
	if [ "$_enabled" = "1" ]
	then
		uci set wireless.default_radio$_radio.wps_pushbutton='1'
		uci set wireless.default_radio$_radio.wps_manufacturer='FlashBox AP'
		uci set wireless.default_radio$_radio.wps_device_name='anlix.io'
	fi
}

get_wifi_local_config() {
	local _ssid_24="$(uci -q get wireless.default_radio0.ssid)"
	local _password_24="$(uci -q get wireless.default_radio0.key)"
	local _channel_24="$(uci -q get wireless.radio0.channel)"
	local _curr_channel_24="$(get_wifi_channel '0')"
	local _hwmode_24="$(get_hwmode_24)"
	local _htmode_24="$(get_htmode_24)"
	local _curr_htmode_24="$(get_wifi_htmode '0')"
	local _state_24="$(get_wifi_state '0')"
	local _txpower_24="$(get_txpower 0)"
	local _ft_24="$(uci -q get wireless.default_radio0.ieee80211r)"
	local _hidden_24="$(uci -q get wireless.default_radio0.hidden)"

	local _is_5ghz_capable="$(is_5ghz_capable)"
	local _ssid_50=""
	local _password_50=""
	local _channel_50=""
	local _curr_channel_50=""
	local _hwmode_50=""
	local _htmode_50=""
	local _curr_htmode_50=""
	local _state_50=""
	local _txpower_50=""
	local _ft_50=""
	local _hidden_50=""
	if [ "$_is_5ghz_capable" = "1" ]
	then
		_ssid_50="$(uci -q get wireless.default_radio1.ssid)"
		_password_50="$(uci -q get wireless.default_radio1.key)"
		_channel_50="$(uci -q get wireless.radio1.channel)"
		_curr_channel_50="$(get_wifi_channel '1')"
		_hwmode_50="$(uci -q get wireless.radio1.hwmode)"
		_htmode_50="$(get_htmode_50)"
		_curr_htmode_50="$(get_wifi_htmode '1')"
		_state_50="$(get_wifi_state '1')"
		_txpower_50="$(get_txpower 1)"
		_ft_50="$(uci -q get wireless.default_radio1.ieee80211r)"
		_hidden_50="$(uci -q get wireless.default_radio1.hidden)"
	fi

	json_cleanup
	json_init
	json_add_string "local_ssid_24" "$_ssid_24"
	json_add_string "local_password_24" "$_password_24"
	json_add_string "local_channel_24" "$_channel_24"
	json_add_string "local_curr_channel_24" "$_curr_channel_24"
	json_add_string "local_hwmode_24" "$_hwmode_24"
	json_add_string "local_htmode_24" "$_htmode_24"
	json_add_string "local_curr_htmode_24" "$_curr_htmode_24"
	json_add_string "local_ft_24" "$_ft_24"
	json_add_string "local_state_24" "$_state_24"
	json_add_string "local_txpower_24" "$_txpower_24"
	json_add_string "local_hidden_24" "$_hidden_24"
	json_add_string "local_5ghz_capable" "$_is_5ghz_capable"
	json_add_string "local_ssid_50" "$_ssid_50"
	json_add_string "local_password_50" "$_password_50"
	json_add_string "local_channel_50" "$_channel_50"
	json_add_string "local_curr_channel_50" "$_curr_channel_50"
	json_add_string "local_hwmode_50" "$_hwmode_50"
	json_add_string "local_htmode_50" "$_htmode_50"
	json_add_string "local_curr_htmode_50" "$_curr_htmode_50"
	json_add_string "local_ft_50" "$_ft_50"
	json_add_string "local_state_50" "$_state_50"
	json_add_string "local_txpower_50" "$_txpower_50"
	json_add_string "local_hidden_50" "$_hidden_50"
	json_dump
	json_close_object
}

save_wifi_parameters() {
	json_cleanup
	json_load_file /root/flashbox_config.json
	json_add_string ssid_24 "$(uci -q get wireless.default_radio0.ssid)"
	json_add_string password_24 "$(uci -q get wireless.default_radio0.key)"
	json_add_string channel_24 "$(uci -q get wireless.radio0.channel)"
	json_add_string hwmode_24 "$(uci -q get wireless.radio0.hwmode)"
	json_add_string htmode_24 "$(get_htmode_24)"
	json_add_string state_24 "$(get_wifi_state '0')"
	json_add_string txpower_24 "$(get_txpower 0)"
	json_add_string hidden_24 "$(uci -q get wireless.default_radio0.hidden)"

	if [ "$(is_5ghz_capable)" == "1" ]
	then
		json_add_string ssid_50 "$(uci -q get wireless.default_radio1.ssid)"
		json_add_string password_50 "$(uci -q get wireless.default_radio1.key)"
		json_add_string channel_50 "$(uci -q get wireless.radio1.channel)"
		json_add_string hwmode_50 "$(uci -q get wireless.radio1.hwmode)"
		json_add_string htmode_50 "$(get_htmode_50)"
		json_add_string state_50 "$(get_wifi_state '1')"
		json_add_string txpower_50 "$(get_txpower 1)"
		json_add_string hidden_50 "$(uci -q get wireless.default_radio1.hidden)"
	fi
	json_dump > /root/flashbox_config.json
	json_close_object
}

set_wifi_local_config() {
	local _do_reload=0

	local _remote_ssid_24="$1"
	local _remote_password_24="$2"
	local _remote_channel_24="$3"
	local _remote_hwmode_24="$4"
	local _remote_htmode_24="$5"
	local _remote_state_24="$6"
	local _remote_txpower_24="$7"
	local _remote_hidden_24="$8"

	local _remote_ssid_50="$9"
	local _remote_password_50="${10}"
	local _remote_channel_50="${11}"
	local _remote_hwmode_50="${12}"
	local _remote_htmode_50="${13}"
	local _remote_state_50="${14}"
	local _remote_txpower_50="${15}"
	local _remote_hidden_50="${16}"

	local _mesh_mode="${17}"

	json_cleanup
	json_load "$(get_wifi_local_config)"
	json_get_var _local_ssid_24 local_ssid_24
	json_get_var _local_password_24 local_password_24
	json_get_var _local_channel_24 local_channel_24
	json_get_var _local_hwmode_24 local_hwmode_24
	json_get_var _local_htmode_24 local_htmode_24
	json_get_var _local_ft_24 local_ft_24
	json_get_var _local_state_24 local_state_24
	json_get_var _local_txpower_24 local_txpower_24
	json_get_var _local_hidden_24 local_hidden_24

	json_get_var _local_ssid_50 local_ssid_50
	json_get_var _local_password_50 local_password_50
	json_get_var _local_channel_50 local_channel_50
	json_get_var _local_hwmode_50 local_hwmode_50
	json_get_var _local_htmode_50 local_htmode_50
	json_get_var _local_ft_50 local_ft_50
	json_get_var _local_state_50 local_state_50
	json_get_var _local_txpower_50 local_txpower_50
	json_get_var _local_hidden_50 local_hidden_50
	json_close_object

	if [ "$_remote_ssid_24" != "" ] && \
		 [ "$_remote_ssid_24" != "$_local_ssid_24" ]
	then
		log "FLASHMAN UPDATER" "Reloading configuration due SSID(2.4GHz)"
		uci set wireless.default_radio0.ssid="$_remote_ssid_24"
		_do_reload=1
	fi
	if [ "$_remote_password_24" != "" ] && \
		 [ "$_remote_password_24" != "$_local_password_24" ]
	then
		log "FLASHMAN UPDATER" "Reloading configuration due password(2.4GHz)"
		uci set wireless.default_radio0.key="$_remote_password_24"
		_do_reload=1
	fi
	if [ "$_remote_channel_24" != "" ] && \
		 [ "$_remote_channel_24" != "$_local_channel_24" ]
	then
		local _newchan="$_remote_channel_24"
		if [ "$(type -t custom_wifi_24_channels)" ] && \
			[ "$(custom_wifi_24_channels|grep -c ' ')" = 0 ] && \
			[ "$_newchan" = "auto" ]
		then
			_newchan="$(custom_wifi_24_channels)"
		fi

		if [ "$_newchan" != "$_local_channel_24" ]
		then
			log "FLASHMAN UPDATER" "Reloading configuration due channel(2.4GHz)"
			uci set wireless.radio0.channel="$_newchan"
			_do_reload=1
		fi
	fi
	if [ "$_remote_hwmode_24" != "" ] && \
		 [ "$_remote_hwmode_24" != "$_local_hwmode_24" ]
	then
		log "FLASHMAN UPDATER" "Reloading configuration due hwmode(2.4GHz)"
		# hostapd use only 11g (11n is defined in htmode)
		[ "$_remote_hwmode_24" = "11g" ] && uci set wireless.radio0.htmode="NOHT"
		[ "$_remote_hwmode_24" = "11n" ] && uci set wireless.radio0.htmode="HT20"
		_do_reload=1
	fi
	if [ "$_remote_htmode_24" != "" ] && \
		 [ "$_remote_htmode_24" != "$_local_htmode_24" ]
	then
		local _newht=$(uci -q get wireless.radio0.htmode)
		if [ "$_newht" != "NOHT" ]
		then
			log "FLASHMAN UPDATER" "Reloading configuration due htmode(2.4GHz)"
			[ "$_remote_htmode_24" = "HT40" ] && uci set wireless.radio0.htmode="HT40"  && uci set wireless.radio0.noscan="1"
			[ "$_remote_htmode_24" = "HT20" ] && uci set wireless.radio0.htmode="HT20" && uci set wireless.radio0.noscan="1"
			[ "$_remote_htmode_24" = "auto" ] && uci set wireless.radio0.htmode="HT40" && uci set wireless.radio0.noscan="0"
			_do_reload=1
		fi
	fi

	if [ -n "$_mesh_mode" ]
	then
		# Set the channel back to what was set in enable_mesh
		# if it is a slave and remote channel is auto
		if [ "$_remote_channel_24" = "auto" ] && 
		   [ "$(is_mesh_slave)" -eq "1" ]
		then
			log "FLASHMAN UPDATER" "Reloading configuration due auto channel in mesh(2.4GHz)"
			uci set wireless.radio0.channel="$_local_channel_24"
			_do_reload=1
		fi

		# Fast transition is disable for now for mesh v2
			
		## Enable Fast Transition
		#if [ "$_mesh_mode" != "0" ] && \
		#	 [ "$_local_ft_24" != "1" ]
		#then
		#	log "FLASHMAN UPDATER" "Reloading configuration due fast transition(2.4GHz)"
		#	change_fast_transition "0" "1"
		#	_do_reload=1
		#fi
		#
		##Disable Fast Transition
		#if [ "$_mesh_mode" == "0" ] && \
		#	 [ "$_local_ft_24" == "1" ]
		#then
		#	log "FLASHMAN UPDATER" "Reloading configuration due fast transition(2.4GHz)"
		#	change_fast_transition "0" "0"
		#	_do_reload=1
		#fi 
	fi

	if [ "$_remote_state_24" != "" ]
	then
		if [ "$_remote_state_24" = "0" ] && [ "$_local_state_24" = "1" ]
		then
			log "FLASHMAN UPDATER" "Reloading configuration due state(2.4GHz)"
			uci set wireless.default_radio0.disabled="1"
			_do_reload=1
		elif [ "$_remote_state_24" = "1" ] && [ "$_local_state_24" = "0" ]
		then
			log "FLASHMAN UPDATER" "Reloading configuration due state(2.4GHz)"
			uci set wireless.default_radio0.disabled="0"
			_do_reload=1
		fi
	fi
	if [ "$_remote_txpower_24" != "" ] && [ "$_remote_txpower_24" != "$_local_txpower_24" ]
	then
		log "FLASHMAN UPDATER" "Reloading configuration due txpower(2.4GHz)"
		_conv_channel=$([ "$_remote_channel_24" ] && echo "$_remote_channel_24" || echo "$_local_channel_24")
		uci set wireless.radio0.txpower="$(convert_txpower "24" "$_conv_channel" "$_remote_txpower_24")"
		_do_reload=1
	fi
	if [ "$_remote_hidden_24" != "" ] && [ "$_remote_hidden_24" != "$_local_hidden_24" ]
	then
		log "FLASHMAN UPDATER" "Reloading configuration due visibility(2.4GHz)"
		uci set wireless.default_radio0.hidden="$_remote_hidden_24"
		_do_reload=1
	fi

	# 5GHz
	if [ "$(is_5ghz_capable)" == "1" ]
	then
		if [ "$_remote_ssid_50" != "" ] && \
			 [ "$_remote_ssid_50" != "$_local_ssid_50" ]
		then
			log "FLASHMAN UPDATER" "Reloading configuration due SSID(5Ghz)"
			uci set wireless.default_radio1.ssid="$_remote_ssid_50"
			_do_reload=1
		fi
		if [ "$_remote_password_50" != "" ] && \
			 [ "$_remote_password_50" != "$_local_password_50" ]
		then
			log "FLASHMAN UPDATER" "Reloading configuration due password(5Ghz)"
			uci set wireless.default_radio1.key="$_remote_password_50"
			_do_reload=1
		fi
		if [ "$_remote_channel_50" != "" ] && \
			 [ "$_remote_channel_50" != "$_local_channel_50" ]
		then
			local _newchan="$_remote_channel_50"
			if [ "$(type -t custom_wifi_50_channels)" ] && \
				[ "$(custom_wifi_50_channels|grep -c ' ')" = 0 ] && \
				[ "$_newchan" = "auto" ]
			then
				_newchan="$(custom_wifi_50_channels)"
			fi

			if [ "$_newchan" != "$_local_channel_50" ]
			then
				log "FLASHMAN UPDATER" "Reloading configuration due channel(5Ghz)"
				uci set wireless.radio1.channel="$_newchan"
				_do_reload=1
			fi
		fi

		if [ "$_remote_htmode_50" != "" ] && \
			 [ "$_remote_htmode_50" != "$_local_htmode_50" ]
		then
			log "FLASHMAN UPDATER" "Reloading configuration due htmode(5Ghz)"
			if [ "$_remote_htmode_50" == "auto" ]
			then
				uci set wireless.radio1.noscan="0"
				[ ! "$(is_5ghz_vht)" ] && uci set wireless.radio1.htmode="HT40"
				[ "$(is_5ghz_vht)" ] && uci set wireless.radio1.htmode="VHT80"
			else
				uci set wireless.radio1.noscan="1"
				if [ "$_remote_htmode_50" == "VHT80" ]
				then
					[ ! "$(is_5ghz_vht)" ] && uci set wireless.radio1.htmode="HT40"
					[ "$(is_5ghz_vht)" ] && uci set wireless.radio1.htmode="VHT80"
				else
					uci set wireless.radio1.htmode="$_remote_htmode_50"
				fi
			fi
			_do_reload=1
		fi

		if [ -n "$_mesh_mode" ]
		then
			# Set the channel back to what was set in enable_mesh
			# if it is a slave and remote channel is auto
			if [ "$_remote_channel_50" = "auto" ] && 
			[ "$(is_mesh_slave)" -eq "1" ]
			then
				log "FLASHMAN UPDATER" "Reloading configuration due auto channel in mesh(5Ghz)"
				uci set wireless.radio1.channel="$_local_channel_50"
				_do_reload=1
			fi

			# Fast transition is disable for now for mesh v2

			# Enable Fast Transition
			#if [ "$_mesh_mode" != "0" ] && \
			#	 [ "$_local_ft_50" != "1" ]
			#then
			#	log "FLASHMAN UPDATER" "Reloading configuration due fast transition(5Ghz)"
			#	change_fast_transition "1" "1"
			#	_do_reload=1
			#fi
			#
			##Disable Fast Transition
			#if [ "$_mesh_mode" == "0" ] && \
			#	 [ "$_local_ft_50" == "1" ]
			#then
			#	log "FLASHMAN UPDATER" "Reloading configuration due fast transition(5Ghz)"
			#	change_fast_transition "1" "0"
			#	_do_reload=1
			#fi
		fi

		if [ "$_remote_state_50" != "" ]
		then
			if [ "$_remote_state_50" = "0" ] && [ "$_local_state_50" = "1" ]
			then
				log "FLASHMAN UPDATER" "Reloading configuration due state(5Ghz)"
				uci set wireless.default_radio1.disabled="1"
				_do_reload=1
			elif [ "$_remote_state_50" = "1" ] && [ "$_local_state_50" = "0" ]
			then
				log "FLASHMAN UPDATER" "Reloading configuration due state(5Ghz)"
				uci set wireless.default_radio1.disabled="0"
				_do_reload=1
			fi
		fi
		if [ "$_remote_txpower_50" != "" ] && [ "$_remote_txpower_50" != "$_local_txpower_50" ]
		then
			log "FLASHMAN UPDATER" "Reloading configuration due txpower(5Ghz)"
			_conv_channel=$([ "$_remote_channel_50" ] && echo "$_remote_channel_50" || echo "$_local_channel_50")
			uci set wireless.radio1.txpower="$(convert_txpower "50" "$_conv_channel" "$_remote_txpower_50")"
			_do_reload=1
		fi
		if [ "$_remote_hidden_50" != "" ] && [ "$_remote_hidden_50" != "$_local_hidden_50" ]
		then
			log "FLASHMAN UPDATER" "Reloading configuration due visibility(5Ghz)"
			uci set wireless.default_radio1.hidden="$_remote_hidden_50"
			_do_reload=1
		fi
	fi

	if [ $_do_reload -eq 1 ]
	then
		uci commit wireless
		save_wifi_parameters
		return 0
	fi
	return 1
}

change_wifi_state() {
	local _state
	local _itf_num
	local _wifi_state
	local _wifi_state_50

	_state=$1
	_itf_num=$2

	if [ "$_state" = "0" ]
	then
		_wifi_state="0"
		_wifi_state_50="0"
	else
		_wifi_state="1"
		_wifi_state_50="1"
	fi
	[ "$_itf_num" = "0" ] && _wifi_state_50=""
	[ "$_itf_num" = "1" ] && _wifi_state=""
	set_wifi_local_config "" "" "" "" "" "$_wifi_state" "" "" \
					"" "" "" "" "" "$_wifi_state_50" "" "" \
					"" && wifi && /etc/init.d/minisapo reload
}

set_wps_push_button() {
	local _state
	local _device0
	local _device1

	_state=$1
	_device0=$(get_radio_phy 0)
	_device1=$(get_radio_phy 1)

	if [ "$_state" = "1" ]
	then
		# Push button will last 2 min active or until first conn succeeds
		if [ "$_device0" == "ra0" ]
		then
			iwpriv ra0 wsc_start 1
			/usr/share/hostapdstats.sh ra0 WPS-PBC-ACTIVE & # Call this once
		else
			hostapd_cli -i wlan0 wps_pbc
		fi

		if [ "$(is_5ghz_capable)" == "1" ] && [ "$_device1" == "rai0" ]
		then
			iwpriv rai0 wsc_start 1
		elif [ "$(is_5ghz_capable)" == "1" ]
		then
			hostapd_cli -i wlan1 wps_pbc
		fi
		return 0
	else
		# Cancel WPS
		if [ "$_device0" == "ra0" ]
		then
			iwpriv ra0 wsc_start 0
			/usr/share/hostapdstats.sh ra0 WPS-PBC-DISABLE # Call this only once
		else
			hostapd_cli -i wlan0 wps_cancel
		fi
		if [ "$(is_5ghz_capable)" == "1" ] && [ "$_device1" == "rai0" ]
		then
			iwpriv rai0 wsc_start 0
		elif [ "$(is_5ghz_capable)" == "1" ]
		then
			hostapd_cli -i wlan1 wps_cancel
		fi
		return 0
	fi
}

get_connected_devices_number() {
	local L1=$(iwinfo $(get_root_ifname 0) a | wc -l)
	local L2=0

	[ "$(is_5ghz_capable)" == "1" ] && L2=$(iwinfo $(get_root_ifname 1) a | wc -l)

	echo $(((L1/5)+(L2/5)))
}
