#!/bin/bash

. /usr/share/libubox/jshn.sh
. /usr/share/functions/device_functions.sh
. /usr/share/functions/network_functions.sh
. /usr/share/functions/custom_wireless_driver.sh


# Check if the device can do Mesh
is_mesh_capable() {
	# If it has an Station ifname, than it can do Mesh
	[ -z "$(get_station_ifname 0)" ] && echo "0" || echo "1"
}

# Set mesh to be Master
set_mesh_master() {
	local _mesh_mode="$1"
	local _local_mesh_mode=$(get_mesh_mode)

	for i in $(uci -q get dhcp.lan.dhcp_option)
	do
		if [ "$i" != "${i#"vendor:ANLIX02,43"}" ]
		then
			uci del_list dhcp.lan.dhcp_option=$i
		fi
	done

	if [ "$_mesh_mode" != "0" ]
	then
		log "MESH" "Enabling mesh mode $_mesh_mode"
		uci add_list dhcp.lan.dhcp_option="vendor:ANLIX02,43,$_mesh_mode"
	else
		log "MESH" "Mesh mode disabled"
	fi
	json_cleanup
	json_load_file /root/flashbox_config.json
	json_add_string mesh_mode "$_mesh_mode"
	json_add_string mesh_master ""
	json_dump > /root/flashbox_config.json
	json_close_object

	uci commit dhcp
	if [ "$(get_bridge_mode_status)" != "y" ]
	then
		/etc/init.d/dnsmasq reload
	fi
}

# Set the mesh to be Slave
set_mesh_slave() {
	local _mesh_mode="$1"
	local _mesh_master="$2"

	log "MESH" "Enabling mesh slave mode $_mesh_mode from master $_mesh_master"
	json_cleanup
	json_load_file /root/flashbox_config.json
	json_add_string mesh_mode "$_mesh_mode"
	json_add_string mesh_master "$_mesh_master"
	json_dump > /root/flashbox_config.json
	json_close_object
}

# Is Mesh Slave
is_mesh_slave() {
	local _mesh_mode=""
	local _mesh_master=""
	json_cleanup
	json_load_file /root/flashbox_config.json
	json_get_var _mesh_mode mesh_mode
	json_get_var _mesh_master mesh_master
	json_close_object

	[ -n "$_mesh_mode" ] && [ "$_mesh_mode" != "0" ] && [ -n "$_mesh_master" ] && echo "1" || echo "0"
}

# Get if the Mesh Mode: 2.4G, 5G or Both
get_mesh_mode() {
	local _mesh_mode=""
	json_cleanup
	json_load_file /root/flashbox_config.json
	json_get_var _mesh_mode mesh_mode
	json_close_object
	[ -z "$_mesh_mode" ] && echo "0" || echo "$_mesh_mode"
}

# Get the Mesh Master BSSID
get_mesh_master() {
	local _mesh_master=""
	json_cleanup
	json_load_file /root/flashbox_config.json
	json_get_var _mesh_master mesh_master
	json_close_object
	echo "$_mesh_master"
}

# Get Mesh SSID from configuration file
get_mesh_id() {
    local _mesh_id=""
	json_cleanup
	json_load_file /root/flashbox_config.json
	json_get_var _mesh_id mesh_id
	json_close_object
	[ "$_mesh_id" ] && echo "$_mesh_id" || echo "Anlix-MESH"
}

# Get Mesh Key from configuration file
get_mesh_key() {
    local _mesh_key=""
	json_cleanup
	json_load_file /root/flashbox_config.json
	json_get_var _mesh_key mesh_key
	json_close_object
	[ "$_mesh_key" ] && echo "$_mesh_key" || echo "tempkey1234"
}

# Change channel automatically for slave or return to auto
change_channel() {
	# $1: Mesh Mode
		# 0: Disable all
		# 1: Cable Only
		# 2: Enable 2.4G and Cable
		# 3: Enable 5G and Cable
		# 4: Enable all
	# $2: Mesh Master

	local _mesh_mode="$1"
	local _mesh_master="$2"

	# Configuration for 2.4G
	if [ "$_mesh_master" ] && [ "$_mesh_mode" -eq "2" ] || [ "$_mesh_mode" -eq "4" ]
	then

		# Get the channel of the Master
		local _channel_2=$(iwinfo $(get_root_ifname 0) scan | sed -n /$_mesh_master/,/Cell/p | grep "Channel" | awk '{print $4}' | head -1)

		# Configure radio to use the channel
		[ "$_channel_2" ] && uci set wireless.radio0.channel="$_channel_2"

	# Otherwise reset the channel
	else
		uci set wireless.radio0.channel="auto"
	fi

	# Configuration for 5G
	if [ "$_mesh_master" ] && [ "$_mesh_mode" -eq "3" ] || [ "$_mesh_mode" -eq "4" ]
	then

		# Get the channel of the Master
		local _channel_5=$(iwinfo $(get_root_ifname 1) scan | sed -n /$_mesh_master/,/Cell/p | grep "Channel" | awk '{print $4}' | head -1)

		# Configure radio to use the channel
		[ "$_channel_5" ] && uci set wireless.radio1.channel="$_channel_5"

	# Otherwise reset the channel
	else
		uci set wireless.radio1.channel="auto"
	fi

	# Commit changes
	uci commit wireless
}

# Turns on/off Mesh
enable_mesh() {
    # $1: Mesh Mode
		# 0: Disable all
		# 1: Cable Only
		# 2: Enable 2.4G and Cable
		# 3: Enable 5G and Cable
		# 4: Enable all
	# $2: Mesh SSID 	(if needed)
	# $3: Mesh Key 		(if needed)

    local _new_mesh_id	
	local _new_mesh_key
	local _mesh_mode="$1"
	local _do_save=0
	local _local_mesh_id="$(get_mesh_id)"
	local _local_mesh_id="$(get_mesh_key)"

    local _mesh_master=$(get_mesh_master)

	local _mac_addr="$(get_mac)"
	local _mac_end=${_mac_addr:15}

    # Check if it needs to change the ssid and key
	if [ "$#" -eq 3 ]
	then
		_new_mesh_id="$2"
		_new_mesh_key="$3"
	else
		_new_mesh_id="$(get_mesh_id)"
		_new_mesh_key="$(get_mesh_key)"
	fi

	# Save configutation to json
	if [ "$_local_mesh_id" != "$_new_mesh_id" ] ||
	   [ "$_local_mesh_key" != "$_new_mesh_key" ]
	then
		json_cleanup
		json_load_file /root/flashbox_config.json
		json_add_string mesh_id "$_new_mesh_id"
		json_add_string mesh_key "$_new_mesh_key"
		json_dump > /root/flashbox_config.json
		json_close_object
	fi

    # Clean all mesh entries before updating
    [ "$(uci -q get wireless.mesh2_ap)" ] && uci delete wireless.mesh2_ap
    [ "$(uci -q get wireless.mesh2_sta)" ] && uci delete wireless.mesh2_sta
    [ "$(uci -q get wireless.mesh5_ap)" ] && uci delete wireless.mesh5_ap
    [ "$(uci -q get wireless.mesh5_sta)" ] && uci delete wireless.mesh5_sta
    _do_save=1


	# Set the channel automatically
	change_channel "$_mesh_mode" "$_mesh_master"


	# Configuration for 2.4G
    if [ "$_mesh_mode" -eq "2" ] || [ "$_mesh_mode" -eq "4" ]
    then
        # If Master, configure AP
        # If Slave, configure STATION
        if [ -z "$_mesh_master" ]
        then
            # Set the configuration for AP 2.4G
			uci set wireless.mesh2_ap=wifi-iface
			uci set wireless.mesh2_ap.device='radio0'
            uci set wireless.mesh2_ap.network='lan'

			# Get the first virtual AP
			uci set wireless.mesh2_ap.ifname="$(get_virtual_ap_ifname "0" "1")"
			
			uci set wireless.mesh2_ap.mode='ap'
            uci set wireless.mesh2_ap.hidden='0'
            uci set wireless.mesh2_ap.disassoc_low_ack='1'
			uci set wireless.mesh2_ap.ssid="$_new_mesh_id"
			uci set wireless.mesh2_ap.encryption='psk2'
			uci set wireless.mesh2_ap.key="$_new_mesh_key"
			uci set wireless.mesh2_ap.disabled='0'
			# Use the mac address and increment the last byte
			uci set wireless.mesh2_ap.macaddr="${_mac_addr::-2}$(printf '%x' $((0x$_mac_end + 0x1)))"

        else
            # Set the configuration for STATION 2.4G
			uci set wireless.mesh2_sta=wifi-iface
			uci set wireless.mesh2_sta.device='radio0'
			uci set wireless.mesh2_sta.ifname="$(get_station_ifname "0")"
			uci set wireless.mesh2_sta.mode='sta'
			# The SSID is needed by Mediatek
			uci set wireless.mesh2_sta.ssid="$_mesh_id"
			uci set wireless.mesh2_sta.bssid="$_mesh_master"
			uci set wireless.mesh2_sta.encryption='psk2'
			uci set wireless.mesh2_sta.key="$_new_mesh_key"
			uci set wireless.mesh2_sta.disabled='0'
        fi
    fi
    
	# Configuration for 5G
    if [ "$_mesh_mode" -eq "3" ] || [ "$_mesh_mode" -eq "4" ]
    then
        # If Master, configure AP
        # If Slave, configure STATION
        if [ -z "$_mesh_master" ]
        then
            # Set the configuration for AP 5G
			uci set wireless.mesh5_ap=wifi-iface
			uci set wireless.mesh5_ap.device='radio1'
            uci set wireless.mesh5_ap.network='lan'

			# Get the first virtual AP
			uci set wireless.mesh5_ap.ifname="$(get_virtual_ap_ifname "1" "1")"

			uci set wireless.mesh5_ap.mode='ap'
            uci set wireless.mesh5_ap.hidden='0'
            uci set wireless.mesh5_ap.disassoc_low_ack='1'
			uci set wireless.mesh5_ap.ssid="$_new_mesh_id"
			uci set wireless.mesh5_ap.encryption='psk2'
			uci set wireless.mesh5_ap.key="$_new_mesh_key"
			uci set wireless.mesh5_ap.disabled='0'
			# Use the mac address and increment the last byte
			uci set wireless.mesh5_ap.macaddr="${_mac_addr::-2}$(printf '%x' $((0x$_mac_end + 0x1)))"

        else
            # Set the configuration for STATION 5G
			uci set wireless.mesh5_sta=wifi-iface
			uci set wireless.mesh5_sta.device='radio1'
			uci set wireless.mesh5_sta.ifname="$(get_station_ifname "1")"
			uci set wireless.mesh5_sta.mode='sta'
			# The SSID is needed by Mediatek
			uci set wireless.mesh5_sta.ssid="$_mesh_id"
			uci set wireless.mesh5_sta.bssid="$_mesh_master"
			uci set wireless.mesh5_sta.encryption='psk2'
			uci set wireless.mesh5_sta.key="$_new_mesh_key"
			uci set wireless.mesh5_sta.disabled='0'
        fi
    fi

    # Save modifications
	if [ $_do_save -eq 1 ]
	then
		uci commit wireless
		return 0
	fi

	return 1
}

# Change the channels automatically
auto_change_mesh_slave_channel() {
	scan_channel(){
		local _new_NCh=""
		local _iface="$1"
		local _mesh_id="$2"
		A=$(iw dev $_iface scan -u);
		while [ "$A" ]
		do
			AP=${A##*BSS }
			A=${A%BSS *}
			case "$AP" in
				*"MESH ID: $_mesh_id"*)
					_new_NCh="$(echo "$AP"|awk 'BEGIN{CH=""}/primary channel/{CH=$4}END{print CH}')"
					;;
			esac
		done
		echo "$_new_NCh"
	}

	local _mesh_mode="$(get_mesh_mode)"
	local _mesh_id="$(get_mesh_id)"
	local _NCh2=""
	local _NCh5=""
	if [ "$_mesh_mode" -eq "2" ] || [ "$_mesh_mode" -eq "4" ]
	then
		log "AUTOCHANNEL" "Scanning MESH channel for mesh0..."
		_NCh2=$(iwinfo $(get_root_ifname 0) scan | sed -n /$_mesh_id/,/Cell/p | grep "Channel" | awk '{print $4}' | head -1)
	fi
	if [ "$_mesh_mode" -eq "3" ] || [ "$_mesh_mode" -eq "4" ]
	then
		log "AUTOCHANNEL" "Scanning MESH channel for mesh1..."
		_NCh5=$(iwinfo $(get_root_ifname 1) scan | sed -n /$_mesh_id/,/Cell/p | grep "Channel" | awk '{print $4}' | head -1)
	fi

	if [ "$_NCh2" ] || [ "$_NCh5" ]
	then
		if set_wifi_local_config "" "" "$_NCh2" "" "" "" "" "" \
			"" "" "$_NCh5" "" "" "" "" "" "$_mesh_mode"
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

set_mesh_rrm() {
	local _need_change=0
	[ "$(get_wifi_state 0)" = "1" ] && ubus -t 15 wait_for hostapd.wlan0 2>/dev/null && _need_change=1
	[ "$(is_5ghz_capable)" = "1" ] && [ "$(get_wifi_state 1)" = "1" ] && \
		ubus -t 15 wait_for hostapd.wlan1 2>/dev/null && _need_change=1

	if [ $_need_change -eq 1 ]
	then
		local rrm_list
		local radios=$(ubus list | grep hostapd.wlan)
		A=$'\n'$(ubus call anlix_sapo get_meshids | jsonfilter -e "@.list[*]")
		while [ "$A" ]
		do
			B=${A##*$'\n'}
			A=${A%$'\n'*}
			rrm_list=$rrm_list",$B"
		done
		for value in ${radios}
		do
			rrm_list=${rrm_list}",$(ubus call ${value} rrm_nr_get_own | jsonfilter -e '$.value')"
		done
		for value in ${radios}
		do
			ubus call ${value} bss_mgmt_enable '{"neighbor_report": true}'
			eval "ubus call ${value} rrm_nr_set '{ \"list\": [ ${rrm_list:1} ] }'"
		done
	fi
}

# Check if there is a Mesh license available
is_mesh_license_available() {
	local _res
	local _slave_mac=$1
	local _is_available=1

	if [ "$FLM_USE_AUTH_SVADDR" == "y" ]
	then
		#
		# WARNING! No spaces or tabs inside the following string!
		#
		local _data
		_data="organization=$FLM_CLIENT_ORG&\
mac=$_slave_mac&\
secret=$FLM_CLIENT_SECRET"

		_res=$(curl -s \
			-A "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1)" \
			--tlsv1.2 --connect-timeout 5 --retry 1 \
			--data "$_data" \
			"https://$FLM_AUTH_SVADDR/api/device/mesh/available")

		local _curl_res=$?
		if [ $_curl_res -eq 0 ]
		then
			json_cleanup
			json_load "$_res" 2>/dev/null
			if [ $? == 0 ]
			then
				json_get_var _is_available is_available
				json_close_object
			else
				log "AUTHENTICATOR" "Invalid answer from controler"
			fi
		else
			log "AUTHENTICATOR" "Error connecting to controler ($_curl_res)"
		fi
	else
		_is_available=0
	fi

	return $_is_available
}

# Check if Mesh is connected
is_mesh_connected() {
	local _mesh_mode="$(get_mesh_mode)"
	local _mesh_master="$(get_mesh_master)"
	local conn=""
	if [ "$_mesh_mode" -eq "2" ] || [ "$_mesh_mode" -eq "4" ]
	then
		local _has_mesh=$(iwinfo $(get_station_ifname 0) assoclist | grep $_mesh_master)
		[ "$_has_mesh" ] && conn="1"
	fi
	if [ "$_mesh_mode" -eq "3" ] || [ "$_mesh_mode" -eq "4" ]
	then
		local _has_mesh=$(iwinfo $(get_station_ifname 1) assoclist | grep $_mesh_master)
		[ "$_has_mesh" ] && conn="1"
	fi
	echo "$conn"
}

# Register Mesh Slaves
set_mesh_slaves() {
	local _mesh_slave="$1"
	if [ "$(is_mesh_master)" = "1" ]
	then
		# Check license availability before proceeding
		if is_mesh_license_available $_mesh_slave
		then
			local _retstatus
			local _status=20
			local _data="id=$(get_mac)&slave=$_mesh_slave"
			local _url="deviceinfo/mesh/add"
			local _res=$(rest_flashman "$_url" "$_data")

			_retstatus=$?
			if [ $_retstatus -eq 0 ]
			then
				json_cleanup
				json_load "$_res"
				json_get_var _is_registered is_registered
				json_close_object
				# value 2 is already registred. No need to do anything
				if [ "$_is_registered" = "1" ]
				then
					log "MESH" "Slave router $_mesh_slave registered successfull"
				fi
				if [ "$_is_registered" = "0" ]
				then
					log "MESH" "Error registering slave router $_mesh_slave"
					_status=21
				fi
			else
				log "MESH" "Error communicating with server for registration"
				_status=21
			fi
		else
			log "MESH" "No license available"
			_status=22
		fi

		json_cleanup
		json_init
		json_add_string mac "$_mesh_slave"
		json_add_int status $_status
		ubus call anlix_sapo notify_sapo "$(json_dump)"
		json_close_object
	fi
}