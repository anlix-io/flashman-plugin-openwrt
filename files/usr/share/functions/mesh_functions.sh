#!/bin/bash

. /usr/share/libubox/jshn.sh
. /usr/share/functions/device_functions.sh
. /usr/share/functions/network_functions.sh
. /usr/share/functions/custom_wireless_driver.sh


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

	# uci set dhcp.lan.ignore='1'
	# uci set network.lan.proto='dhcp'

	log "MESH" "Enabling mesh slave mode $_mesh_mode from master $_mesh_master"
	json_cleanup
	json_load_file /root/flashbox_config.json
	json_add_string mesh_mode "$_mesh_mode"
	json_add_string mesh_master "$_mesh_master"
	json_dump > /root/flashbox_config.json
	json_close_object
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

# Get the Mesh flag: Master, Slave or Both
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

# Turns on/off Mesh
enable_mesh() {
    # $1: Mesh Mode
		# 0: Disable all
		# 1: Cable Only
		# 2: Enable 2.4G and Cable
		# 3: Enable 5G and Cable
		# 4: Enable all
	# $3: Station SSID 	(if needed)
	# $4: Station Key 	(if needed)

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


	# Configuration for 2.4G
    if [ "$_mesh_mode" -eq "2" ] || [ "$_mesh_mode" -eq "4" ]
    then
        # If Master, configure AP
        # If Slave, configure STATION
        if [ -z "$_mesh_master" ]
        then
            # Set the configuration for 2.4G
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
			uci set wireless.mesh2_ap.macaddr="${_mac_addr::-2}$((_mac_end + 1))"

        else
            # Set the configuration for 2.4G
			uci set wireless.mesh2_sta=wifi-iface
			uci set wireless.mesh2_sta.device='radio0'
			uci set wireless.mesh2_sta.ifname="$(get_station_ifname "0")"
			uci set wireless.mesh2_sta.mode='sta'
			uci set wireless.mesh2_sta.ssid="$_new_mesh_id"
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
            # Set the configuration for 5G
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
			uci set wireless.mesh5_ap.macaddr="${_mac_addr::-2}$((_mac_end + 1))"

        else
            # Set the configuration for 5G
			uci set wireless.mesh5_sta=wifi-iface
			uci set wireless.mesh5_sta.device='radio1'
			uci set wireless.mesh5_sta.ifname="$(get_station_ifname "1")"
			uci set wireless.mesh5_sta.mode='sta'
			uci set wireless.mesh5_sta.ssid="$_new_mesh_id"
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