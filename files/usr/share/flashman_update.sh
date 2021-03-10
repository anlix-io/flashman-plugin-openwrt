#!/bin/sh

. /usr/share/flashman_init.conf
. /usr/share/libubox/jshn.sh
. /usr/share/flash_image.sh
. /usr/share/functions/common_functions.sh
. /usr/share/functions/system_functions.sh
. /usr/share/functions/device_functions.sh
. /usr/share/functions/wireless_functions.sh
. /usr/share/functions/network_functions.sh
. /usr/share/functions/firewall_functions.sh
. /usr/share/functions/api_functions.sh
. /usr/share/functions/zabbix_functions.sh

lock /tmp/lock_updater

# If a command hash is provided, check if it should still be done
COMMANDHASH=""
if [ "$1" != "" ]
then
	if [ -f /root/to_do_hashes ] && [ "$(grep $1 /root/to_do_hashes)" != "" ]
	then
		TIMEOUT="$(grep $1 /root/to_do_hashes | tail -n 1)"
		COMMANDHASH="$(echo $TIMEOUT | cut -d " " -f 1)"
		TIMEOUT="$(echo $TIMEOUT | cut -d " " -f 2)"
		if [ "$(date +%s)" -gt "$TIMEOUT" ]
		then
			log "FLASHMAN UPDATER" "Provided hash received after command timeout"
			log "FLASHMAN UPDATER" "Done"
			lock -u /tmp/lock_updater
			exit 0
		fi
	else
		log "FLASHMAN UPDATER" "Provided hash is not in the to do file"
		log "FLASHMAN UPDATER" "Done"
		lock -u /tmp/lock_updater
		exit 0
	fi
fi

log "FLASHMAN UPDATER" "Start ..."

if is_authenticated
then
	log "FLASHMAN UPDATER" "Authenticated ..."

	# Get WiFi data
	json_cleanup
	json_load "$(get_wifi_local_config)"
	json_get_var _local_ssid_24 local_ssid_24
	json_get_var _local_password_24 local_password_24
	json_get_var _local_channel_24 local_channel_24
	json_get_var _local_curr_channel_24 local_curr_channel_24
	json_get_var _local_hwmode_24 local_hwmode_24
	json_get_var _local_htmode_24 local_htmode_24
	json_get_var _local_curr_htmode_24 local_curr_htmode_24
	json_get_var _local_state_24 local_state_24
	json_get_var _local_txpower_24 local_txpower_24
	json_get_var _local_hidden_24 local_hidden_24
	json_get_var _local_5ghz_capable local_5ghz_capable
	json_get_var _local_ssid_50 local_ssid_50
	json_get_var _local_password_50 local_password_50
	json_get_var _local_channel_50 local_channel_50
	json_get_var _local_curr_channel_50 local_curr_channel_50
	json_get_var _local_hwmode_50 local_hwmode_50
	json_get_var _local_curr_htmode_50 local_curr_htmode_50
	json_get_var _local_htmode_50 local_htmode_50
	json_get_var _local_state_50 local_state_50
	json_get_var _local_txpower_50 local_txpower_50
	json_get_var _local_hidden_50 local_hidden_50
	json_close_object
	# Get config data
	json_cleanup
	json_load_file /root/flashbox_config.json
	json_get_var _has_upgraded_version has_upgraded_version
	json_get_var _hard_reset_info hard_reset_info
	json_get_var _local_bridge_enabled bridge_mode
	json_get_var _local_bridge_switch_disable bridge_disable_switch
	json_get_var _local_bridge_fix_ip bridge_fix_ip
	json_get_var _local_bridge_fix_gateway bridge_fix_gateway
	json_get_var _local_bridge_fix_dns bridge_fix_dns
	json_get_var _local_bridge_did_reset bridge_did_reset
	json_get_var _local_did_change_wan did_change_wan_local
	json_get_var _local_mesh_mode mesh_mode
	json_close_object

	# Get WPS state if exists
	_local_wps_state="0"
	if [ -f "/tmp/wps_state.json" ]
	then
		json_cleanup
		json_load_file /tmp/wps_state.json
		json_get_var _local_wps_state wps_content
		json_close_object
	fi

	[ ! "$_local_mesh_mode" ] && _local_mesh_mode="0"

	# If bridge is active, we cannot use get_wan_type, use flashman_init.conf
	_local_wan_type="$(get_wan_type)"
	if [ "$_local_bridge_enabled" = "y" ]
	then
		_local_wan_type="$FLM_WAN_PROTO"
	fi

	# Translate some variables from y/n to 1/0
	if [ "$_local_bridge_enabled" = "y" ]
	then
		_local_bridge_enabled=1
	else
		_local_bridge_enabled=0
	fi
	if [ "$_local_bridge_switch_disable" = "y" ]
	then
		_local_bridge_switch_disable=1
	else
		_local_bridge_switch_disable=0
	fi

	_local_enabled_ipv6="$(get_ipv6_enabled)"

	# Report if a hard reset has occured
	if [ "$_hard_reset_info" = "1" ]
	then
		log "FLASHMAN UPDATER" "Sending HARD RESET Information to server"
		if [ -e /sysupgrade.tgz ]
		then
			rm /sysupgrade.tgz
		fi
	fi

	#
	# WARNING! No spaces or tabs inside the following string!
	#
	_data="id=$(get_mac)&\
flm_updater=1&\
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
lan_no_dns_proxy=$(get_use_dns_proxy)&\
ipv6_enabled=$_local_enabled_ipv6&\
wifi_ssid=$_local_ssid_24&\
wifi_password=$_local_password_24&\
wifi_channel=$_local_channel_24&\
wifi_curr_channel=$_local_curr_channel_24&\
wifi_band=$_local_htmode_24&\
wifi_curr_band=$_local_curr_htmode_24&\
wifi_mode=$_local_hwmode_24&\
wifi_state=$_local_state_24&\
wifi_power=$_local_txpower_24&\
wifi_hidden=$_local_hidden_24&\
wifi_5ghz_capable=$_local_5ghz_capable&\
wifi_ssid_5ghz=$_local_ssid_50&\
wifi_password_5ghz=$_local_password_50&\
wifi_channel_5ghz=$_local_channel_50&\
wifi_curr_channel_5ghz=$_local_curr_channel_50&\
wifi_band_5ghz=$_local_htmode_50&\
wifi_curr_band_5ghz=$_local_curr_htmode_50&\
wifi_mode_5ghz=$_local_hwmode_50&\
wifi_state_5ghz=$_local_state_50&\
wifi_power_5ghz=$_local_txpower_50&\
wifi_hidden_5ghz=$_local_hidden_50&\
connection_type=$_local_wan_type&\
ntp=$(ntp_anlix)&\
hardreset=$_hard_reset_info&\
upgfirm=$_has_upgraded_version&\
sysuptime=$(sys_uptime)&\
wanuptime=$(wan_uptime)&\
wpsstate=$_local_wps_state"
	if [ "$_local_bridge_did_reset" = "y" ] || [ "$_local_did_change_wan" = "y" ]
	then
		_data="$_data&\
bridge_enabled=$_local_bridge_enabled&\
bridge_switch_disable=$_local_bridge_switch_disable&\
bridge_fix_ip=$_local_bridge_fix_ip&\
bridge_fix_gateway=$_local_bridge_fix_gateway&\
bridge_fix_dns=$_local_bridge_fix_dns"
	fi
	if [ "$_local_did_change_wan" = "y" ]
	then
		_data="$_data&local_change_wan=1"
	fi
	_url="deviceinfo/syn/"
	_res=$(rest_flashman "$_url" "$_data")

	if [ "$?" -eq 1 ]
	then
		log "FLASHMAN UPDATER" "Fail in Rest Flashman! Aborting..."
		lock -u /tmp/lock_updater
		exit 0
	else
		json_cleanup
		json_load "$_res"
		json_get_var _do_update do_update
		json_get_var _do_newprobe do_newprobe
		json_get_var _release_id release_id
		json_get_var _connection_type connection_type
		json_get_var _pppoe_user pppoe_user
		json_get_var _pppoe_password pppoe_password
		json_get_var _lan_addr lan_addr
		json_get_var _lan_netmask lan_netmask
		json_get_var _lan_no_dns_proxy lan_no_dns_proxy
		json_get_var _ipv6_enabled ipv6_enabled
		json_get_var _wifi_ssid_24 wifi_ssid
		json_get_var _wifi_password_24 wifi_password
		json_get_var _wifi_channel_24 wifi_channel
		json_get_var _wifi_htmode_24 wifi_band
		json_get_var _wifi_hwmode_24 wifi_mode
		json_get_var _wifi_txpower_24 wifi_power
		json_get_var _wifi_hidden_24 wifi_hidden
		json_get_var _wifi_state wifi_state
		json_get_var _wifi_ssid_50 wifi_ssid_5ghz
		json_get_var _wifi_password_50 wifi_password_5ghz
		json_get_var _wifi_channel_50 wifi_channel_5ghz
		json_get_var _wifi_htmode_50 wifi_band_5ghz
		json_get_var _wifi_hwmode_50 wifi_mode_5ghz
		json_get_var _wifi_state_50 wifi_state_5ghz
		json_get_var _wifi_txpower_50 wifi_power_5ghz
		json_get_var _wifi_hidden_50 wifi_hidden_5ghz
		json_get_var _app_password app_password
		json_get_var _forward_index forward_index
		json_get_var _blocked_devices_index blocked_devices_index
		json_get_var _upnp_devices_index upnp_devices_index
		json_get_var _zabbix_psk zabbix_psk
		json_get_var _zabbix_fqdn zabbix_fqdn
		json_get_var _zabbix_active zabbix_active
		json_get_var _bridge_mode_enabled bridge_mode_enabled
		json_get_var _bridge_mode_switch_disable bridge_mode_switch_disable
		json_get_var _bridge_mode_ip bridge_mode_ip
		json_get_var _bridge_mode_gateway bridge_mode_gateway
		json_get_var _bridge_mode_dns bridge_mode_dns
		json_get_var _did_change_vlan did_change_vlan
		json_get_var _mesh_mode mesh_mode
		json_get_var _mesh_master mesh_master
		json_get_var _mesh_id mesh_id
		json_get_var _mesh_key mesh_key

		_local_bridge_enabled=$(get_bridge_mode_status)

		_blocked_macs=""
		_blocked_devices=""
		if json_get_type TYPE blocked_devices && [ "$TYPE" == array ]
		then
			json_select blocked_devices
			INDEX="1"  # Json library starts indexing at 1
			while json_get_type TYPE $INDEX && [ "$TYPE" = string ]; do
				json_get_var _device "$((INDEX++))"
				_blocked_devices="$_blocked_devices""$_device"$'\n'
				_mac_addr=$(echo "$_device" | head -c 17)
				_blocked_macs="$_mac_addr $_blocked_macs"
			done
			json_select ..
		fi
		_named_devices=""
		if json_get_type TYPE named_devices && [ "$TYPE" == array ]
		then
			json_select named_devices
			INDEX="1"  # Json library starts indexing at 1
			while json_get_type TYPE $INDEX && [ "$TYPE" = string ]; do
				json_get_var _device "$((INDEX++))"
				_named_devices="$_named_devices""$_device"$'\n'
			done
			json_select ..
		fi
		# Remove trailing newline / space
		_blocked_macs=${_blocked_macs::-1}
		_blocked_devices=${_blocked_devices::-1}
		_named_devices=${_named_devices::-1}
		json_close_object

		if [ "$_do_update" == "1" ]
		then
			log "FLASHMAN UPDATER" "Reflashing ..."
			run_reflash $_release_id
			lock -u /tmp/lock_updater
			exit 1
		fi

		if [ "$_did_change_vlan" = "y" ]
		then
			_vlan=${_res#*\"vlan\":}
			_vlan=${_vlan%%\}*}
			_vlan="$_vlan}"
			_config="$(cat /root/flashbox_config.json)"
			_before=${_config%\"vlan\"*}
			if [ $(( ${#_before} < ${#_config} )) = 1 ]; then
				_before="$_before\"vlan\": "
				_after=${_config#*\"vlan\": }
				_after=${_after#*\}}
			else
				_before=${_config% \}}
				_before="$_before, \"vlan\": "
				_after=" }"
			fi
			_new_config="$_before$_vlan$_after"
			echo "$_new_config" > /root/flashbox_config.json
		fi
		# Reset the reset flags when we receive syn reply
		if [ "$_local_bridge_did_reset" = "y" ]
		then
			json_cleanup
			json_load_file /root/flashbox_config.json
			json_add_string bridge_did_reset "n"
			json_dump > /root/flashbox_config.json
			json_close_object
		fi
		if [ "$_local_did_change_wan" = "y" ]
		then
			json_cleanup
			json_load_file /root/flashbox_config.json
			json_add_string did_change_wan_local "n"
			json_dump > /root/flashbox_config.json
			json_close_object
		fi

		if [ "$_hard_reset_info" = "1" ]
		then
			json_cleanup
			json_load_file /root/flashbox_config.json
			json_add_string hard_reset_info "0"
			json_dump > /root/flashbox_config.json
			json_close_object
		fi

		if [ "$_has_upgraded_version" = "1" ]
		then
			json_cleanup
			json_load_file /root/flashbox_config.json
			json_add_string has_upgraded_version "0"
			json_dump > /root/flashbox_config.json
			json_close_object
		fi

		if [ "$_do_newprobe" = "1" ]
		then
			log "FLASHMAN UPDATER" "Router Registered in Flashman Successfully!"
			# On a new probe, force a new registry in mqtt secret
			reset_mqtt_secret > /dev/null
		fi

		# Send boot log information if boot is completed and probe is registered!
		if [ ! -e /tmp/boot_completed ]
		then
			log "FLASHMAN UPDATER" "Sending BOOT log"
			send_boot_log "boot"
			echo "0" > /tmp/boot_completed
		fi

		if [ "$_ipv6_enabled" ] && [ "$_local_enabled_ipv6" != "$_ipv6_enabled" ]
		then
			if [ "$_ipv6_enabled" = "1" ]
			then
				enable_ipv6 
			else
				disable_ipv6
			fi
			/etc/init.d/network restart
			/etc/init.d/miniupnpd reload
		fi

		# Ignore changes if in bridge mode
		if [ "$_local_bridge_enabled" != "y" ]
		then
			# WAN connection type update
			set_wan_type "$_connection_type" "$_pppoe_user" "$_pppoe_password"

			# PPPoE update
			set_pppoe_credentials "$_pppoe_user" "$_pppoe_password"

			# LAN connection subnet update
			set_lan_subnet "$_lan_addr" "$_lan_netmask"
			# If LAN has changed then reload port forward mapping
			if [ $? -eq 0 ]
			then
				update_port_forward
			fi

			# Change use of local router DNS proxy
			set_use_dns_proxy "$_lan_no_dns_proxy"
		fi

		# WiFi update
		log "FLASHMAN UPDATER" "Updating Wireless ..."
		_need_wifi_reload=0
		if [ "$_mesh_mode" ] && [ "$_mesh_mode" != "$_local_mesh_mode" ] 
		then
			if [ -z "$_mesh_master" ]
			then
				set_mesh_master_mode "$_mesh_mode"
			else
				set_mesh_slave_mode "$_mesh_mode" "$_mesh_master"
			fi
			enable_mesh_routing "$_mesh_mode" "$_mesh_id" "$_mesh_key" && _need_wifi_reload=1
			/etc/init.d/minisapo restart
		fi

		set_wifi_local_config "$_wifi_ssid_24" "$_wifi_password_24" \
									"$_wifi_channel_24" "$_wifi_hwmode_24" \
									"$_wifi_htmode_24" "$_wifi_state" \
									"$_wifi_txpower_24" "$_wifi_hidden_24" \
									"$_wifi_ssid_50" "$_wifi_password_50" \
									"$_wifi_channel_50" "$_wifi_hwmode_50" \
									"$_wifi_htmode_50" "$_wifi_state_50" \
									"$_wifi_txpower_50" "$_wifi_hidden_50" \
									"$_mesh_mode" && _need_wifi_reload=1
		[ $_need_wifi_reload -eq 1 ] && wifi reload && /etc/init.d/minisapo reload

		# Flash App password update
		if [ "$_app_password" == "" ]
		then
			log "FLASHMAN UPDATER" "Removing app access password ..."
			reset_flashapp_pass
		elif [ "$_app_password" != "$(get_flashapp_pass)" ]
		then
			log "FLASHMAN UPDATER" "Updating app access password ..."
			set_flashapp_pass "$_app_password"
		fi

		# Named devices file update - always do this to avoid file diff logic
		log "FLASHMAN UPDATER" "Writing named devices file..."
		echo -n "$_named_devices" > /tmp/named_devices

		# Check for updates in blocked devices
		# Ignore changes if in bridge mode
		if [ "$_local_bridge_enabled" != "y" ]
		then
			_local_dindex=$(get_forward_indexes "blocked_devices_index")
			if [ "$_local_dindex" != "$_blocked_devices_index" ]
			then
				update_blocked_devices "$_blocked_devices" "$_blocked_macs" \
															"$_blocked_devices_index"
			fi
		fi

		# Update zabbix parameters as necessary
		if [ "$ZBX_SUPPORT" == "y" ]
		then
			set_zabbix_params "$_zabbix_psk" "$_zabbix_fqdn" "$_zabbix_active"
		fi

		# Check for updates in port forward mapping
		# Ignore changes if in bridge mode
		if [ "$_local_bridge_enabled" != "y" ]
		then
			_local_findex=$(get_forward_indexes "forward_index")
			[ "$_local_findex" != "$_forward_index" ] && update_port_forward

			# Check for updates in upnp allowed devices mapping
			_local_uindex=$(get_forward_indexes "upnp_devices_index")
			[ "$_local_uindex" != "$_upnp_devices_index" ] && update_upnp_devices
		fi

		# Store completed command hash if one was provided
		if [ "$COMMANDHASH" != "" ]
		then
			echo "$COMMANDHASH" >> /root/done_hashes
		fi

		_update_vlan=0
		[ "$_did_change_vlan" = "y" ] && _update_vlan=1
		# Update bridge mode information
		if [ "$_bridge_mode_enabled" = "y" ] && [ "$_local_bridge_enabled" != "y" ]
		then
			log "FLASHMAN UPDATER" "Enabling bridge mode..."
			enable_bridge_mode "y" "n" "$_bridge_mode_switch_disable" "$_bridge_mode_ip" \
												 "$_bridge_mode_gateway" "$_bridge_mode_dns"
			_update_vlan=0
		elif [ "$_bridge_mode_enabled" = "y" ] && [ "$_local_bridge_enabled" = "y" ]
		then
			log "FLASHMAN UPDATER" "Updating bridge mode parameters..."
			update_bridge_mode "n" "$_bridge_mode_switch_disable" "$_bridge_mode_ip" \
												"$_bridge_mode_gateway" "$_bridge_mode_dns"
			_update_vlan=0
		elif [ "$_bridge_mode_enabled" = "n" ] && [ "$_local_bridge_enabled" = "y" ]
		then
			log "FLASHMAN UPDATER" "Disabling bridge mode..."
			disable_bridge_mode
		fi
		[ $_update_vlan ] && [ "$(type -t set_vlan_on_boot)" == "" ] && update_vlan
		
	fi
else
	log "FLASHMAN UPDATER" "Fail Authenticating device!"
	lock -u /tmp/lock_updater
	exit 0
fi
log "FLASHMAN UPDATER" "Done"
lock -u /tmp/lock_updater
exit 1
