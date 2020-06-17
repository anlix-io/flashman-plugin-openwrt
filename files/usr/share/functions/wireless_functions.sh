#!/bin/sh

. /usr/share/libubox/jshn.sh
. /usr/share/functions/device_functions.sh

is_ralink() {
	[ "$(uci -q get wireless.@wifi-device[0].type)" == "ralink" ] && echo "1" || echo ""
}

get_hwmode_24() {
	local _htmode_24="$(uci -q get wireless.radio0.htmode)"
	[ "$_htmode_24" = "NOHT" ] && echo "11g" || echo "11n"
}

get_htmode_24() {
	local _htmode_24="$(uci -q get wireless.radio0.htmode)"
	[ "$_htmode_24" = "NOHT" ] && echo "HT20" || echo "$_htmode_24"
}

get_wifi_local_config() {
	local _ssid_24="$(uci -q get wireless.@wifi-iface[0].ssid)"
	local _password_24="$(uci -q get wireless.@wifi-iface[0].key)"
	local _channel_24="$(uci -q get wireless.radio0.channel)"
	local _hwmode_24="$(get_hwmode_24)"
	local _htmode_24="$(get_htmode_24)"
	local _state_24="$(get_wifi_state '0')"
	local _ft_24="$(uci -q get wireless.@wifi-iface[0].ieee80211r)"

	local _is_5ghz_capable="$(is_5ghz_capable)"
	local _ssid_50="$(uci -q get wireless.@wifi-iface[1].ssid)"
	local _password_50="$(uci -q get wireless.@wifi-iface[1].key)"
	local _channel_50="$(uci -q get wireless.radio1.channel)"
	local _hwmode_50="$(uci -q get wireless.radio1.hwmode)"
	local _htmode_50="$(uci -q get wireless.radio1.htmode)"
	local _state_50="$(get_wifi_state '1')"
	local _ft_50="$(uci -q get wireless.@wifi-iface[1].ieee80211r)"

	json_cleanup
	json_init
	json_add_string "local_ssid_24" "$_ssid_24"
	json_add_string "local_password_24" "$_password_24"
	json_add_string "local_channel_24" "$_channel_24"
	json_add_string "local_hwmode_24" "$_hwmode_24"
	json_add_string "local_htmode_24" "$_htmode_24"
	json_add_string "local_state_24" "$_state_24"
	json_add_string "local_5ghz_capable" "$_is_5ghz_capable"
	json_add_string "local_ssid_50" "$_ssid_50"
	json_add_string "local_password_50" "$_password_50"
	json_add_string "local_channel_50" "$_channel_50"
	json_add_string "local_hwmode_50" "$_hwmode_50"
	json_add_string "local_htmode_50" "$_htmode_50"
	json_add_string "local_state_50" "$_state_50"
	echo "$(json_dump)"
	json_close_object
}

save_wifi_parameters() {
	json_cleanup
	json_load_file /root/flashbox_config.json
	json_add_string ssid_24 "$(uci -q get wireless.@wifi-iface[0].ssid)"
	json_add_string password_24 "$(uci -q get wireless.@wifi-iface[0].key)"
	json_add_string channel_24 "$(uci -q get wireless.@wifi-device[0].channel)"
	json_add_string hwmode_24 "$(uci -q get wireless.@wifi-device[0].hwmode)"
	json_add_string htmode_24 "$(uci -q get wireless.@wifi-device[0].htmode)"
	if [ "$(uci -q get wireless.@wifi-device[0].type)" == "ralink" ]
	then
		json_add_string state_24 "$([ -e /etc/modules.d/50-mt7628 ] && echo "0" || echo "1")"
	else
		_dstate=$(uci -q get wireless.@wifi-device[0].disabled)
		json_add_string state_24 "$([ "$_dstate" == "1" ] && echo "0" || echo "1")"
	fi
	if [ "$(is_5ghz_capable)" == "1" ]
	then
		json_add_string ssid_50 "$(uci -q get wireless.@wifi-iface[1].ssid)"
		json_add_string password_50 "$(uci -q get wireless.@wifi-iface[1].key)"
		json_add_string channel_50 "$(uci -q get wireless.@wifi-device[1].channel)"
		json_add_string hwmode_50 "$(uci -q get wireless.@wifi-device[1].hwmode)"
		json_add_string htmode_50 "$(uci -q get wireless.@wifi-device[1].htmode)"
		_dstate=$(uci -q get wireless.@wifi-device[1].disabled)
		json_add_string state_50 "$([ "$_dstate" == "1" ] && echo "0" || echo "1")"
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
		uci set wireless.@wifi-iface[0].ssid="$_remote_ssid_24"
		_do_reload=1
	fi
	if [ "$_remote_password_24" != "" ] && \
		 [ "$_remote_password_24" != "$_local_password_24" ]
	then
		uci set wireless.@wifi-iface[0].key="$_remote_password_24"
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
		if [ "$(is_ralink)" ]
		then
			uci set wireless.radio0.hwmode="$_remote_hwmode_24"
			[ "$_remote_hwmode_24" = "11n" ] && uci set wireless.radio0.wifimode="9"
			[ "$_remote_hwmode_24" = "11g" ] && uci set wireless.radio0.wifimode="4"
		fi
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
			if [ "$(is_ralink)" ]
			then
				if [ "$_remote_htmode_24" = "HT40" ]
				then
					uci set wireless.radio0.ht_bsscoexist="0"
					uci set wireless.radio0.bw="1"
				elif [ "$_remote_htmode_24" = "HT20" ]
				then
					uci set wireless.radio0.ht_bsscoexist="1"
					uci set wireless.radio0.bw="0"
				fi
			fi
			_do_reload=1
		fi
	fi

	# Enable Fast Transition
	if [ "$_mesh_mode" != "0" ] && \
		 [ "$_local_ft_24" != "1" ]
	then
		uci set wireless.@wifi-iface[0].ieee80211r="1"
		uci set wireless.@wifi-iface[0].ieee80211v="1"
		uci set wireless.@wifi-iface[0].bss_transition="1"
		uci set wireless.@wifi-iface[0].ieee80211k="1"
		_do_reload=1
	fi

	#Disable Fast Transition
	if [ "$_mesh_mode" == "0" ] && \
		 [ "$_local_ft_24" == "1" ]
	then
		uci delete wireless.@wifi-iface[0].ieee80211r
		uci delete wireless.@wifi-iface[0].ieee80211v
		uci delete wireless.@wifi-iface[0].bss_transition
		uci delete wireless.@wifi-iface[0].ieee80211k
		_do_reload=1
	fi 

	if [ "$_remote_state_24" != "" ] && \
		 [ "$_remote_state_24" = "0" ] && \
		 [ "$_local_state_24" = "1" ]
	then
		save_wifi_local_config
		store_disable_wifi "0"
		save_wifi_parameters
		_do_reload=0
	elif [ "$_remote_state_24" != "" ] && \
			 [ "$_remote_state_24" = "1" ] && \
			 [ "$_local_state_24" = "0" ]
	then
		save_wifi_local_config
		store_enable_wifi "0"
		save_wifi_parameters
		_do_reload=0
	fi

	# 5GHz
	if [ "$(uci -q get wireless.@wifi-iface[1])" ]
	then
		if [ "$_remote_ssid_50" != "" ] && \
			 [ "$_remote_ssid_50" != "$_local_ssid_50" ]
		then
			uci set wireless.@wifi-iface[1].ssid="$_remote_ssid_50"
			_do_reload=1
		fi
		if [ "$_remote_password_50" != "" ] && \
			 [ "$_remote_password_50" != "$_local_password_50" ]
		then
			uci set wireless.@wifi-iface[1].key="$_remote_password_50"
			_do_reload=1
		fi
		if [ "$_remote_channel_50" != "" ] && \
			 [ "$_remote_channel_50" != "$_local_channel_50" ]
		then
			uci set wireless.radio1.channel="$_remote_channel_50"
			_do_reload=1
		fi
		if [ "$_remote_hwmode_50" != "" ] && \
			 [ "$_remote_hwmode_50" != "$_local_hwmode_50" ]
		then
			# Standard cfg80211 use only "11a" ("na" mode is defined in htmode)
			if [ "$(is_ralink)" ]
			then
				[ "$_remote_hwmode_50" = "11ac" ] && uci set wireless.radio1.wifimode="15"
				[ "$_remote_hwmode_50" = "11na" ] && uci set wireless.radio1.wifimode="11"
				_do_reload=1
			fi
		fi
		if [ "$_remote_htmode_50" != "" ] && \
			 [ "$_remote_htmode_50" != "$_local_htmode_50" ]
		then
			uci set wireless.radio1.htmode="$_remote_htmode_50"
			if [ "$(is_ralink)" ]
			then
				if [ "$_remote_htmode_50" = "VHT80" ]
				then
					uci set wireless.radio1.noscan="1"
					uci set wireless.radio1.ht_bsscoexist="0"
					uci set wireless.radio1.bw="2"
				elif [ "$_remote_htmode_50" = "VHT40" ]
				then
					uci set wireless.radio1.noscan="1"
					uci set wireless.radio1.ht_bsscoexist="0"
					uci set wireless.radio1.bw="1"
				elif [ "$_remote_htmode_50" = "HT40" ]
				then
					uci set wireless.radio1.noscan="1"
					uci set wireless.radio1.ht_bsscoexist="0"
					uci set wireless.radio1.bw="1"
				elif [ "$_remote_htmode_50" = "VHT20" ]
				then
					uci set wireless.radio1.noscan="0"
					uci set wireless.radio1.ht_bsscoexist="1"
					uci set wireless.radio1.bw="0"
				elif [ "$_remote_htmode_50" = "HT20" ]
				then
					uci set wireless.radio1.noscan="0"
					uci set wireless.radio1.ht_bsscoexist="1"
					uci set wireless.radio1.bw="0"
				fi
			fi
			_do_reload=1
		fi

		# Enable Fast Transition
		if [ "$_mesh_mode" != "0" ] && \
			 [ "$_local_ft_50" != "1" ]
		then
			uci set wireless.@wifi-iface[1].ieee80211r="1"
			uci set wireless.@wifi-iface[1].ieee80211v="1"
			uci set wireless.@wifi-iface[1].bss_transition="1"
			uci set wireless.@wifi-iface[1].ieee80211k="1"
			_do_reload=1
		fi

		#Disable Fast Transition
		if [ "$_mesh_mode" == "0" ] && \
			 [ "$_local_ft_50" == "1" ]
		then
			uci delete wireless.@wifi-iface[1].ieee80211r
			uci delete wireless.@wifi-iface[1].ieee80211v
			uci delete wireless.@wifi-iface[1].bss_transition
			uci delete wireless.@wifi-iface[1].ieee80211k
			_do_reload=1
		fi

		if [ "$_remote_state_50" != "" ] && \
			 [ "$_remote_state_50" = "0" ] && \
			 [ "$_local_state_50" = "1" ]
		then
			save_wifi_local_config
			store_disable_wifi "1"
			save_wifi_parameters
			_do_reload=0
		elif [ "$_remote_state_50" != "" ] && \
				 [ "$_remote_state_50" = "1" ] && \
				 [ "$_local_state_50" = "0" ]
		then
			save_wifi_local_config
			store_enable_wifi "1"
			save_wifi_parameters
			_do_reload=0
		fi
	fi

	if [ $_do_reload -eq 1 ]
	then
		save_wifi_local_config
		save_wifi_parameters
		wifi reload
	fi
}

enable_mesh_routing() {
	local _mesh_mode=$1
	local _do_save=0

	if [ "$(type -t is_mesh_routing_capable)" ]
	then
		if [ "$(is_mesh_routing_capable)" -gt "0" ]
		then
			if [ "$_mesh_mode" -eq "2" ] || [ "$_mesh_mode" -eq "4" ]
			then
				if [ "$(is_mesh_routing_capable)" -eq "1" ] || [ "$(is_mesh_routing_capable)" -eq "3" ]
				then
					uci set wireless.mesh2=wifi-iface
					uci set wireless.mesh2.device='radio0'
					uci set wireless.mesh2.ifname='mesh0'
					uci set wireless.mesh2.network='lan'
					uci set wireless.mesh2.mode='mesh'
					uci set wireless.mesh2.mesh_id='anlix'
					uci set wireless.mesh2.encryption='psk2'
					uci set wireless.mesh2.key='tempkey1234'
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
				if [ "$(is_mesh_routing_capable)" -eq "2" ] || [ "$(is_mesh_routing_capable)" -eq "3" ]
				then
					uci set wireless.mesh5=wifi-iface
					uci set wireless.mesh5.device='radio1'
					uci set wireless.mesh5.ifname='mesh1'
					uci set wireless.mesh5.network='lan'
					uci set wireless.mesh5.mode='mesh'
					uci set wireless.mesh5.mesh_id='anlix'
					uci set wireless.mesh5.encryption='psk2'
					uci set wireless.mesh5.key='tempkey1234'
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
			uci commit
			wifi reload
		fi
	fi
}

change_wifi_state() {
	local _state
	local _itf_num

	_state=$1
	_itf_num=$2

	if [ "_$_state" = "0" ]
	then
		store_disable_wifi "$_itf_num"
	else
		store_enable_wifi "$_itf_num"
	fi
}
