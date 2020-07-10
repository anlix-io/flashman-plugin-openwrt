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
	[ "$_htmode_24" = "NOHT" ] && echo "HT20" || echo "$_htmode_24"
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
			echo "44"
		;;
	esac
}

get_wifi_local_config() {
	local _ssid_24="$(uci -q get wireless.default_radio0.ssid)"
	local _password_24="$(uci -q get wireless.default_radio0.key)"
	local _channel_24="$(uci -q get wireless.radio0.channel)"
	local _hwmode_24="$(get_hwmode_24)"
	local _htmode_24="$(get_htmode_24)"
	local _state_24="$(get_wifi_state '0')"
	local _ft_24="$(uci -q get wireless.default_radio0.ieee80211r)"

	local _is_5ghz_capable="$(is_5ghz_capable)"
	local _ssid_50="$(uci -q get wireless.default_radio1.ssid)"
	local _password_50="$(uci -q get wireless.default_radio1.key)"
	local _channel_50="$(uci -q get wireless.radio1.channel)"
	local _hwmode_50="$(uci -q get wireless.radio1.hwmode)"
	local _htmode_50="$(uci -q get wireless.radio1.htmode)"
	local _state_50="$(get_wifi_state '1')"
	local _ft_50="$(uci -q get wireless.default_radio1.ieee80211r)"

	json_cleanup
	json_init
	json_add_string "local_ssid_24" "$_ssid_24"
	json_add_string "local_password_24" "$_password_24"
	json_add_string "local_channel_24" "$_channel_24"
	json_add_string "local_hwmode_24" "$_hwmode_24"
	json_add_string "local_htmode_24" "$_htmode_24"
	json_add_string "local_ft_24" "$_ft_24"
	json_add_string "local_state_24" "$_state_24"
	json_add_string "local_5ghz_capable" "$_is_5ghz_capable"
	json_add_string "local_ssid_50" "$_ssid_50"
	json_add_string "local_password_50" "$_password_50"
	json_add_string "local_channel_50" "$_channel_50"
	json_add_string "local_hwmode_50" "$_hwmode_50"
	json_add_string "local_htmode_50" "$_htmode_50"
	json_add_string "local_ft_50" "$_ft_50"
	json_add_string "local_state_50" "$_state_50"
	echo "$(json_dump)"
	json_close_object
}

save_wifi_parameters() {
	json_cleanup
	json_load_file /root/flashbox_config.json
	json_add_string ssid_24 "$(uci -q get wireless.default_radio0.ssid)"
	json_add_string password_24 "$(uci -q get wireless.default_radio0.key)"
	json_add_string channel_24 "$(uci -q get wireless.radio0.channel)"
	json_add_string hwmode_24 "$(uci -q get wireless.radio0.hwmode)"
	json_add_string htmode_24 "$(uci -q get wireless.radio0.htmode)"
	json_add_string state_24 "$(get_wifi_state '0')"

	if [ "$(is_5ghz_capable)" == "1" ]
	then
		json_add_string ssid_50 "$(uci -q get wireless.default_radio1.ssid)"
		json_add_string password_50 "$(uci -q get wireless.default_radio1.key)"
		json_add_string channel_50 "$(uci -q get wireless.radio1.channel)"
		json_add_string hwmode_50 "$(uci -q get wireless.radio1.hwmode)"
		json_add_string htmode_50 "$(uci -q get wireless.radio1.htmode)"
		json_add_string state_50 "$(get_wifi_state '1')"
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

	local _remote_ssid_50="$7"
	local _remote_password_50="$8"
	local _remote_channel_50="$9"
	local _remote_hwmode_50="$10"
	local _remote_htmode_50="$11"
	local _remote_state_50="$12"

	local _mesh_mode="$13"

	json_cleanup
	json_load "$(get_wifi_local_config)"
	json_get_var _local_ssid_24 local_ssid_24
	json_get_var _local_password_24 local_password_24
	json_get_var _local_channel_24 local_channel_24
	json_get_var _local_hwmode_24 local_hwmode_24
	json_get_var _local_htmode_24 local_htmode_24
	json_get_var _local_ft_24 local_ft_24
	json_get_var _local_state_24 local_state_24

	json_get_var _local_ssid_50 local_ssid_50
	json_get_var _local_password_50 local_password_50
	json_get_var _local_channel_50 local_channel_50
	json_get_var _local_hwmode_50 local_hwmode_50
	json_get_var _local_htmode_50 local_htmode_50
	json_get_var _local_ft_50 local_ft_50
	json_get_var _local_state_50 local_state_50
	json_close_object

	if [ "$_remote_ssid_24" != "" ] && \
		 [ "$_remote_ssid_24" != "$_local_ssid_24" ]
	then
		uci set wireless.default_radio0.ssid="$_remote_ssid_24"
		_do_reload=1
	fi
	if [ "$_remote_password_24" != "" ] && \
		 [ "$_remote_password_24" != "$_local_password_24" ]
	then
		uci set wireless.default_radio0.key="$_remote_password_24"
		_do_reload=1
	fi
	if [ "$_remote_channel_24" != "" ] && \
		 [ "$_remote_channel_24" != "$_local_channel_24" ]
	then
		uci set wireless.radio0.channel="$_remote_channel_24"
		_do_reload=1
	fi
	if [ "$_remote_hwmode_24" != "" ] && \
		 [ "$_remote_hwmode_24" != "$_local_hwmode_24" ]
	then
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
			uci set wireless.radio0.htmode="$_remote_htmode_24"
			[ "$_remote_htmode_24" = "HT40" ] && uci set wireless.radio0.noscan="1"
			[ "$_remote_htmode_24" = "HT20" ] && uci set wireless.radio0.noscan="0"
			_do_reload=1
		fi
	fi

	if [ -n "$_mesh_mode" ]
	then
		local _new_channel="$([ "$_remote_channel_24" != "" ] && echo "$_remote_channel_24" || echo $_local_channel_24)"
		if [ "$_mesh_mode" -eq "2" ] || [ "$_mesh_mode" -eq "4" ] && [ "$_new_channel" = "auto" ]
		then
			#MESH cant run auto!
			_new_channel="$(auto_channel_selection wlan0)"
			uci set wireless.radio0.channel="$_new_channel"
			_do_reload=1
		fi

		# Enable Fast Transition
		if [ "$_mesh_mode" != "0" ] && \
			 [ "$_local_ft_24" != "1" ]
		then
			uci set wireless.default_radio0.ieee80211r="1"
			uci set wireless.default_radio0.ieee80211v="1"
			uci set wireless.default_radio0.bss_transition="1"
			uci set wireless.default_radio0.ieee80211k="1"
			_do_reload=1
		fi

		#Disable Fast Transition
		if [ "$_mesh_mode" == "0" ] && \
			 [ "$_local_ft_24" == "1" ]
		then
			uci delete wireless.default_radio0.ieee80211r
			uci delete wireless.default_radio0.ieee80211v
			uci delete wireless.default_radio0.bss_transition
			uci delete wireless.default_radio0.ieee80211k
			_do_reload=1
		fi 
	fi

	if [ "$_remote_state_24" != "" ]
	then
		if [ "$_remote_state_24" = "0" ] && [ "$_local_state_24" = "1" ]
		then
			uci set wireless.default_radio0.disabled="1"
			_do_reload=1
		elif [ "$_remote_state_24" = "1" ] && [ "$_local_state_24" = "0" ]
		then
			uci set wireless.default_radio0.disabled="0"
			_do_reload=1
		fi
	fi

	# 5GHz
	if [ "$(is_5ghz_capable)" == "1" ]
	then
		if [ "$_remote_ssid_50" != "" ] && \
			 [ "$_remote_ssid_50" != "$_local_ssid_50" ]
		then
			uci set wireless.default_radio1.ssid="$_remote_ssid_50"
			_do_reload=1
		fi
		if [ "$_remote_password_50" != "" ] && \
			 [ "$_remote_password_50" != "$_local_password_50" ]
		then
			uci set wireless.default_radio1.key="$_remote_password_50"
			_do_reload=1
		fi
		if [ "$_remote_channel_50" != "" ] && \
			 [ "$_remote_channel_50" != "$_local_channel_50" ]
		then
			uci set wireless.radio1.channel="$_remote_channel_50"
			_do_reload=1
		fi

		if [ "$_remote_htmode_50" != "" ] && \
			 [ "$_remote_htmode_50" != "$_local_htmode_50" ]
		then
			uci set wireless.radio1.htmode="$_remote_htmode_50"
			if [ ! "$(is_5ghz_vht)" ]
			then
				if [ "$_remote_htmode_50" != "HT40" ] ||
					[ "$_remote_htmode_50" != "HT20" ]
				then
					uci set wireless.radio1.htmode="HT40"
				fi
			fi
			_do_reload=1
		fi

		if [ -n "$_mesh_mode" ]
		then
			local _new_channel="$([ "$_remote_channel_50" != "" ] && echo "$_remote_channel_50" || echo $_local_channel_50)"
			if [ "$_mesh_mode" -eq "3" ] || [ "$_mesh_mode" -eq "4" ] && [ "$_new_channel" = "auto" ]
			then
				#MESH cant run auto!
				_new_channel="$(auto_channel_selection wlan1)"
				uci set wireless.radio1.channel="$_new_channel"
				_do_reload=1
			fi

			# Enable Fast Transition
			if [ "$_mesh_mode" != "0" ] && \
				 [ "$_local_ft_50" != "1" ]
			then
				uci set wireless.default_radio1.ieee80211r="1"
				uci set wireless.default_radio1.ieee80211v="1"
				uci set wireless.default_radio1.bss_transition="1"
				uci set wireless.default_radio1.ieee80211k="1"
				_do_reload=1
			fi

			#Disable Fast Transition
			if [ "$_mesh_mode" == "0" ] && \
				 [ "$_local_ft_50" == "1" ]
			then
				uci delete wireless.default_radio1.ieee80211r
				uci delete wireless.default_radio1.ieee80211v
				uci delete wireless.default_radio1.bss_transition
				uci delete wireless.default_radio1.ieee80211k
				_do_reload=1
			fi
		fi

		if [ "$_remote_state_50" != "" ]
		then
			if [ "$_remote_state_50" = "0" ] && [ "$_local_state_50" = "1" ]
			then
				uci set wireless.default_radio1.disabled="1"
				_do_reload=1
			elif [ "$_remote_state_50" = "1" ] && [ "$_local_state_50" = "0" ]
			then
				uci set wireless.default_radio1.disabled="0"
				_do_reload=1
			fi
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

get_mesh_id() {
	local _mesh_id=""
	json_cleanup
	json_load_file /root/flashbox_config.json
	json_get_var _mesh_id mesh_id
	json_close_object
	[ "$_mesh_id" ] && echo "$_mesh_id" || echo "anlix"
}

get_mesh_key() {
	local _mesh_key=""
	json_cleanup
	json_load_file /root/flashbox_config.json
	json_get_var _mesh_key mesh_key
	json_close_object
	[ "$_mesh_key" ] && echo "$_mesh_key" || echo "tempkey1234"
}

enable_mesh_routing() {
	local _new_mesh_id
	local _new_mesh_key
	local _mesh_mode=$1
	local _do_save=0
	local _local_mesh_id=$(get_mesh_id)
	if [ "$#" -eq 3 ]
	then
		_new_mesh_id=$2
		_new_mesh_key=$3
	else
		_new_mesh_id="$(get_mesh_id)"
		_new_mesh_key="$(get_mesh_key)"
	fi

	if [ "$_local_mesh_id" != "$_new_mesh_id" ]
	then
		json_cleanup
		json_load_file /root/flashbox_config.json
		json_add_string mesh_id "$_new_mesh_id"
		json_add_string mesh_key "$_new_mesh_key"
		json_dump > /root/flashbox_config.json
		json_close_object
	fi

	if [ "$(type -t is_mesh_routing_capable)" ]
	then
		local _mrc=$(is_mesh_routing_capable)
		if [ "$_mrc" -gt "0" ]
		then
			if [ "$_mesh_mode" -eq "2" ] || [ "$_mesh_mode" -eq "4" ]
			then
				if [ "$_mrc" -eq "1" ] || [ "$_mrc" -eq "3" ]
				then
					uci set wireless.mesh2=wifi-iface
					uci set wireless.mesh2.device='radio0'
					uci set wireless.mesh2.ifname='mesh0'
					uci set wireless.mesh2.network='lan'
					uci set wireless.mesh2.mode='mesh'
					uci set wireless.mesh2.mesh_id="$_new_mesh_id"
					uci set wireless.mesh2.encryption='psk2'
					uci set wireless.mesh2.key="$_new_mesh_key"
					_do_save=1
				fi
			else
				if [ "$(uci -q get wireless.mesh2)" ]
				then
					uci delete wireless.mesh2
					_do_save=1
				fi
			fi
			if [ "$_mesh_mode" -eq "3" ] || [ "$_mesh_mode" -eq "4" ]
			then
				if [ "$_mrc" -eq "2" ] || [ "$_mrc" -eq "3" ]
				then
					uci set wireless.mesh5=wifi-iface
					uci set wireless.mesh5.device='radio1'
					uci set wireless.mesh5.ifname='mesh1'
					uci set wireless.mesh5.network='lan'
					uci set wireless.mesh5.mode='mesh'
					uci set wireless.mesh5.mesh_id="$_new_mesh_id"
					uci set wireless.mesh5.encryption='psk2'
					uci set wireless.mesh5.key="$_new_mesh_key"
					_do_save=1
				fi
			else
				if [ "$(uci -q get wireless.mesh5)" ]
				then
					uci delete wireless.mesh5
					_do_save=1
				fi
			fi
		fi

		if [ $_do_save -eq 1 ]
		then
			uci commit wireless
			return 0
		fi
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

	if [ "_$_state" = "0" ]
	then
		_wifi_state="0"
		_wifi_state_50="0"
	else
		_wifi_state="1"
		_wifi_state_50="1"
	fi
	[ "$_itf_num" = "0" ] && _wifi_state_50=""
	[ "$_itf_num" = "1" ] && _wifi_state=""
	set_wifi_local_config "" "" "" "" "" "$_wifi_state" \
					"" "" "" "" "" "$_wifi_state_50" \
					"" && wifi reload && /etc/init.d/minisapo reload
}

auto_change_mesh_slave_channel() {
	scan_channel(){
		local _NCh=""
		A=$(iw dev $1 scan -u);
		while [ "$A" ]
		do
			AP=${A##*BSS }
			A=${A%BSS *}
			case "$AP" in
				*"MESH ID"*)
					_NCh="$(echo "$AP"|awk 'BEGIN{OT="";CH=""}/MESH ID/{OT=$3}/primary channel/{CH=$4}END{print CH" "OT}')"
					;;
			esac
		done
		echo "$_NCh"
	}

	local _mesh_mode="$(get_mesh_mode)"
	local _NCh2=""
	local _NCh5=""
	if [ "$_mesh_mode" -eq "2" ] || [ "$_mesh_mode" -eq "4" ]
	then
		log "AUTOCHANNEL" "Scanning MESH channel for mesh0..."
		if iw dev mesh0 info 1>/dev/null 2> /dev/null
		then
			_NCh2=$(scan_channel mesh0)
			[ "$_NCh2" ] && [ "${_NCh2##* }" = "$(get_mesh_id)" ] && _NCh2="${_NCh2% *}"
		fi
	fi
	if [ "$_mesh_mode" -eq "3" ] || [ "$_mesh_mode" -eq "4" ]
	then
		log "AUTOCHANNEL" "Scanning MESH channel for mesh1..."
		if iw dev mesh1 info 1>/dev/null 2> /dev/null
		then
			_NCh5=$(scan_channel mesh1)
			[ "$_NCh5" ] && [ "${_NCh5##* }" = "$(get_mesh_id)" ] && _NCh5="${_NCh5% *}"
		fi
	fi

	if [ "$_NCh2" ] || [ "$_NCh5" ]
	then
		if set_wifi_local_config "" "" "$_NCh2" "" "" "" "" "" \
			"$_NCh5" "" "" "" "$_mesh_mode"
		then
			log "AUTOCHANNEL" "MESH Channel change ($_NCh2) ($_NCh5)"
			wifi reload
		else
			log "AUTOCHANNEL" "No need to change MESH channel"
		fi
	else
		log "AUTOCHANNEL" "No MESH signal found"
	fi
}
