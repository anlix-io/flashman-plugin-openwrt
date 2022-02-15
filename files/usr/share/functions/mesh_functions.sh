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

	if [ "$_mesh_mode" != "0" ]
	then
		log "MESH" "Enabling mesh mode $_mesh_mode"
	else
		log "MESH" "Mesh mode disabled"
	fi
	json_cleanup
	json_load_file /root/flashbox_config.json
	json_add_string mesh_mode "$_mesh_mode"
	json_add_string mesh_master ""
	json_dump > /root/flashbox_config.json
	json_close_object
}

# Save all bssids in the mesh
set_mesh_devices_2() {
	json_cleanup
	json_load_file /root/flashbox_config.json
	json_add_string devices_bssid_mesh2 "$@"
	json_dump > /root/flashbox_config.json
	json_close_object
}

set_mesh_devices_5() {
	json_cleanup
	json_load_file /root/flashbox_config.json
	json_add_string devices_bssid_mesh5 "$@"
	json_dump > /root/flashbox_config.json
	json_close_object
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

# Get all bssids in the mesh
# After updating from v1 to v2, it doesnt have the "_devices_bssid" field in /root/flashbox_config.json
get_mesh_devices() {
	# $1: 2.4G or 5G
		# 0: 2.4G
		# 1: 5G
	local _mesh_wifi="$1"
	local _devices_bssid=""

	json_cleanup
	json_load_file /root/flashbox_config.json
	
	# Choose between 2.4G and 5G
	if [ "$_mesh_wifi" -eq "0" ]
	then
		json_get_var _devices_bssid devices_bssid_mesh2
	elif [ "$_mesh_wifi" -eq "1" ]
	then
		json_get_var _devices_bssid devices_bssid_mesh5
	fi

	json_close_object

	echo "$_devices_bssid"
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

# Get cell number from iwinfo
get_iwinfo_cell() {
	# $1: Iwinfo Data
	# $2: Cell Number

	local _iwinfo_data="$1"
	local _cell_num="$2"
	local _cell_num_end=""

	# Format cell number
	if [ "$_cell_num" -lt "9" ]
	then
		# Just add 0 to the left
		_cell_num_end="$(($_cell_num + 1))"
		_cell_num_end="0${_cell_num_end}"
		_cell_num="0${_cell_num}"

	elif [ "$_cell_num" -eq "9" ]
	then
		# Just add 0 to the left, only in _cell_num
		_cell_num_end="$(($_cell_num + 1))"
		_cell_num_end="${_cell_num_end}"
		_cell_num="0${_cell_num}"

	else
		# Just the number
		_cell_num_end="$(($_cell_num + 1))"
		_cell_num="${_cell_num}"

	fi

	# Get only one Cell
	local _cell="$(echo "$_iwinfo_data" | awk '/Cell '"$_cell_num"'/{f=1} /Cell '"$_cell_num_end"'/{f=0} f')"

	echo "$_cell"
}

# Get MAC Address based on the SSID
find_mac_address() {
	# $1: Iwinfo Data
	# $2: Mesh SSID or BSSID

	local _iwinfo_data="$1"
	local _mesh_id="$2"

	# Get the quantity of cells
	local _total_cells="$(echo "$_iwinfo_data" | grep Cell | awk '{print $2}' | tail -1)"
	local _mac_addr=""

	# Remove left zeros
	_total_cells=${_total_cells#0}

	# Loop through all cells and find mac address
	if [ "$_total_cells" ] && [ "$_mesh_id" ]
	then
		for _cell_num in $(seq 1 $_total_cells)
		do
			local _cell="$(get_iwinfo_cell "$_iwinfo_data" "$_cell_num")"

			# Check if it has the SSID or the BSSID
			if [ "$(echo "$_cell" | grep -E "(Address|ESSID)" | grep "$_mesh_id")" ]
			then
				# Assign mac and exit, 5th element of the line
				_mac_addr="$(echo "$_cell" | grep Address | awk '{print $5}' | tail -1)"
				break
			fi
		done
	fi

	echo "$_mac_addr"
}

# Get Channel based on the SSID
find_channel() {
	# $1: Iwinfo Data
	# $2: Mesh SSID or BSSID

	local _iwinfo_data="$1"
	local _mesh_id="$2"

	# Get the quantity of cells
	local _total_cells="$(echo "$_iwinfo_data" | grep Cell | awk '{print $2}' | tail -1)"
	local _channel=""

	# Remove left zeros
	_total_cells=${_total_cells#0}

	# Loop through all cells and find the channel
	if [ "$_total_cells" ] && [ "$_mesh_id" ]
	then
		for _cell_num in $(seq 1 $_total_cells)
		do
			local _cell="$(get_iwinfo_cell "$_iwinfo_data" "$_cell_num")"

			# Check if it has the SSID or the BSSID
			if [ "$(echo "$_cell" | grep -E "(Address|ESSID)" | grep "$_mesh_id")" ]
			then
				# Assign channel and exit
				# The channel is on the same line as the mode, 4th item
				_channel="$(echo "$_cell" | grep Mode | awk '{print $4}' | tail -1)"
				break
			fi
		done
	fi

	echo "$_channel"
}

# Get the mac address, the channel and the signal quality of the best quality device
mac_ch_signal_from_bssid() {
	# $1: Iwinfo Data
	# $2: Mesh BSSID devices 

	local _iwinfo_data="$1"
	shift
	local _devices_bssid_mesh="$@"

	local _quality_best=""
	local _quality_new=""
	local _bssid_best=""
	local _bssid_new=""
	local _channel=""

	local _index="2"

	# Get the first bssid and quality
	_bssid_new="$(echo "$_devices_bssid_mesh" | awk '{print $1}')"
	_quality_new="$(find_quality "$_iwinfo_data" "$_bssid_new")"

	while [ ! -z "$_bssid_new" ]
	do
		if [ -z "$_bssid_best" ] || [ -z "$_quality_best" ] || [ "$_quality_new" -gt "$_quality_best" ]
		then
			_bssid_best="$_bssid_new"
			_quality_best="$_quality_new"
		fi

		_bssid_new="$(echo "$_devices_bssid_mesh" | awk '{print $'"$_index"'}')"
		_quality_new="$(find_quality "$_iwinfo_data" "$_bssid_new")"
		_index=$(($_index + 1))
	done

	echo "$_bssid_best $(find_channel "$_iwinfo_data" "$_bssid_best") $_quality_best"
}

# Get Quality based on the SSID
find_quality() {
	# $1: Iwinfo Data
	# $2: Mesh SSID or BSSID

	local _iwinfo_data="$1"
	local _mesh_id="$2"

	# Get the quantity of cells
	local _total_cells="$(echo "$_iwinfo_data" | grep Cell | awk '{print $2}' | tail -1)"
	local _quality=""

	# Remove left zeros
	_total_cells=${_total_cells#0}

	# Loop through all cells and find the quality
	if [ "$_total_cells" ] && [ "$_mesh_id" ]
	then
		for _cell_num in $(seq 1 $_total_cells)
		do
			local _cell="$(get_iwinfo_cell "$_iwinfo_data" "$_cell_num")"

			# Check if it has the SSID or the BSSID
			if [ "$(echo "$_cell" | grep -E "(Address|ESSID)" | grep "$_mesh_id")" ]
			then
				# Assign quality and exit, 2nd element of the line
				_quality="$(echo "$_cell" | grep Signal | awk '{print $2}' | tail -1)"
				break
			fi
		done
	fi

	echo "$_quality"
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
	local _local_mesh_id="$(get_mesh_id)"
	local _local_mesh_key="$(get_mesh_key)"

	local _mesh_master=$(get_mesh_master)

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

	# Configuration for 2.4G
	if [ "$_mesh_mode" -eq "2" ] || [ "$_mesh_mode" -eq "4" ]
	then
		# Set the configuration for AP 2.4G
		uci set wireless.mesh2_ap=wifi-iface
		uci set wireless.mesh2_ap.device='radio0'
		uci set wireless.mesh2_ap.network='lan'

		# Get the first virtual AP
		uci set wireless.mesh2_ap.ifname="$(get_mesh_ap_ifname "0")"

		uci set wireless.mesh2_ap.mode='ap'
		uci set wireless.mesh2_ap.hidden='1'
		uci set wireless.mesh2_ap.disassoc_low_ack='1'
		uci set wireless.mesh2_ap.ssid="$_new_mesh_id"
		uci set wireless.mesh2_ap.encryption='psk2'
		uci set wireless.mesh2_ap.key="$_new_mesh_key"
		uci set wireless.mesh2_ap.disabled='0'
		# This address is set on realteks, 
		# read from an existing interface on mediateks
		# and runtime generated on atheros 
		uci set wireless.mesh2_ap.macaddr="$(get_mesh_ap_bssid 0)"

		if [ "$_mesh_master" ]
		then
			# Set the configuration for STATION 2.4G
			# All stations are disabled until we detect with one to use
			uci set wireless.mesh2_sta=wifi-iface
			uci set wireless.mesh2_sta.device='radio0'
			uci set wireless.mesh2_sta.network='lan'
			uci set wireless.mesh2_sta.ifname="$(get_station_ifname "0")"
			uci set wireless.mesh2_sta.mode='sta'
			uci set wireless.mesh2_sta.ssid="$_new_mesh_id"
			uci set wireless.mesh2_sta.encryption='psk2'
			uci set wireless.mesh2_sta.key="$_new_mesh_key"
			uci set wireless.mesh2_sta.disabled='1'
			uci set wireless.mesh2_sta.anlix_ap='1'
			
			# Atheros specific properties
			[ -n "$(get_station_ifname 0 | grep ath)" ] && uci set wireless.mesh2_sta.extap='1'
			
		fi
	fi
	
	# Configuration for 5G
	if [ "$(is_5ghz_capable)" == "1" ]
	then
		if [ "$_mesh_mode" -eq "3" ] || [ "$_mesh_mode" -eq "4" ]
		then
			# Set the configuration for AP 5G
			uci set wireless.mesh5_ap=wifi-iface
			uci set wireless.mesh5_ap.device='radio1'
			uci set wireless.mesh5_ap.network='lan'

			# Get the first virtual AP
			uci set wireless.mesh5_ap.ifname="$(get_mesh_ap_ifname "1")"

			uci set wireless.mesh5_ap.mode='ap'
			uci set wireless.mesh5_ap.hidden='1'
			uci set wireless.mesh5_ap.disassoc_low_ack='1'
			uci set wireless.mesh5_ap.ssid="$_new_mesh_id"
			uci set wireless.mesh5_ap.encryption='psk2'
			uci set wireless.mesh5_ap.key="$_new_mesh_key"
			uci set wireless.mesh5_ap.disabled='0'
			# This address is set on realteks, 
			# read from an existing interface on mediateks
			# and runtime generated on atheros
			uci set wireless.mesh5_ap.macaddr="$(get_mesh_ap_bssid 1)"

			if [ "$_mesh_master" ]
			then
				# Set the configuration for STATION 5G
				# All stations are disabled until we detect with one to use
				uci set wireless.mesh5_sta=wifi-iface
				uci set wireless.mesh5_sta.device='radio1'
				uci set wireless.mesh5_sta.network='lan'
				uci set wireless.mesh5_sta.ifname="$(get_station_ifname "1")"
				uci set wireless.mesh5_sta.mode='sta'
				uci set wireless.mesh5_sta.ssid="$_new_mesh_id"
				uci set wireless.mesh5_sta.encryption='psk2'
				uci set wireless.mesh5_sta.key="$_new_mesh_key"
				uci set wireless.mesh5_sta.disabled='1'
				uci set wireless.mesh5_sta.anlix_ap='1'
				
				# Atheros specific properties
				[ -n "$(get_station_ifname 1 | grep ath)" ] && uci set wireless.mesh5_sta.extap='1'
				
			fi
		fi
	fi

	# Save modifications
	uci commit wireless
	return 0
}

update_mesh_link() {
	local _mesh_id="$(get_mesh_id)"
	local _mesh_mode="$(get_mesh_mode)"

	local _iwinfo_2g_data=""
	local _iwinfo_5g_data=""

	local _rssi_2g=""
	local _rssi_5g=""

	# Mac address and channel for 2.4G
	local _bssid_2g=""
	local _bssid_5g=""
	local _channel_2g=""
	local _channel_5g=""

	# Scan
	if [ "$_mesh_mode" -eq "2" ] || [ "$_mesh_mode" -eq "4" ]
	then
		local _mac_channel_rssi=""
		local _mesh_bssid="$(get_mesh_devices 0)"
		local _root_24="$(get_root_ifname 0)"
		local R0 R1 R2

		log "MESHLINK" "Scanning MESH APs in 2.4GHz ..."
		ifconfig "$_root_24" up 
		_iwinfo_2g_data="$(iwinfo $_root_24 scan)"


		_mac_channel_rssi="$(mac_ch_signal_from_bssid "$_iwinfo_2g_data" $_mesh_bssid)"
		get_data 3 R $_mac_channel_rssi

		_bssid_2g="$R0"
		_channel_2g="$R1"
		_rssi_2g="$R2"

		[ "$_rssi_2g" ] && log "MESHLINK" "Found MESH AP in 2.4GHz ($_rssi_2g) ..."
	fi

	if [ "$_mesh_mode" -eq "3" ] || [ "$_mesh_mode" -eq "4" ]
	then
		if [ "$(is_5ghz_capable)" == "1" ]
		then
			local _mac_channel_rssi=""
			local _mesh_bssid="$(get_mesh_devices 1)"
			local _root_50="$(get_root_ifname 1)"
			local R0 R1 R2

			log "MESHLINK" "Scanning MESH APs in 5GHz ..."
			ifconfig "$_root_50" up 
			_iwinfo_5g_data="$(iwinfo $_root_50 scan)"

			_mac_channel_rssi="$(mac_ch_signal_from_bssid "$_iwinfo_5g_data" $_mesh_bssid)"
			get_data 3 R $_mac_channel_rssi

			_bssid_5g="$R0"
			_channel_5g="$R1"
			_rssi_5g="$R2"

			[ "$_rssi_5g" ] && log "MESHLINK" "Found MESH AP in 5GHz ($_rssi_5g) ..."
		fi
	fi

	#Uplinks with rssi higher that -70, discard
	if [ ! -z "$_rssi_5g" ] && [ "$_rssi_5g" -lt "-70" ]
	then
		_rssi_5g=""
		log "MESHLINK" "Discart 5GHz RSSI!"
	fi

	if [ ! -z "$_rssi_2g" ] && [ "$_rssi_2g" -lt "-70" ]
	then
		_rssi_2g=""
		log "MESHLINK" "Discart 2.4GHz RSSI!"
	fi

	# Can't find an uplink!
	if [ -z "$_rssi_5g" ] && [ -z "$_rssi_2g" ] 
	then
		log "MESHLINK" "No MESH AP Found!"
		return 0
	fi

	# Check the best option (RSSI) to connect to
	# If there is a 5GHz radio with at least -55 dbm, priorize it.
	# if not, use a 2.4.
	if [ ! -z "$_rssi_5g" ] && ([ "$_rssi_5g" -ge "-55" ] || [ -z "$_rssi_2g" ])
	then
		# Set the configuration for STATION 5G
		if [ "$(uci -q get wireless.radio1.channel)" != "$_channel_5g" ] || 
			[ "$(uci -q get wireless.mesh5_sta.bssid)" != "$_bssid_5g" ] ||
			[ "$(uci -q get wireless.mesh5_sta.disabled)" != "0" ]
		then
			uci set wireless.mesh5_sta.bssid="$_bssid_5g"
			uci set wireless.mesh5_sta.disabled='0'
			uci set wireless.mesh2_sta.disabled='1'

			if set_wifi_local_config "" "" "auto" "" "" "" "" "" \
				"" "" "$_channel_5g" "" "" "" "" "" "$_mesh_mode"
			then
				log "MESHLINK" "Change 5Ghz Backbone ($_channel_5g) ($_bssid_5g) ..."
				wifi reload
				sleep 5
				# Atheros stations needs some extra time to connect and prevent a deadloop on backbone probing
				[ -n "$(uci -q get wireless.mesh5_sta.ifname | grep ath )" ] && sleep 15
			else
				log "MESHLINK" "FAIL in change 5Ghz Backbone ($_channel_5g) ($_bssid_5g) ..."
			fi
		else
			log "MESHLINK" "Keep 5Ghz Backbone ($_channel_5g) ($_bssid_5g) ..."
		fi
	else
		# Set the configuration for STATION 2.4G
		if [ "$(uci -q get wireless.radio0.channel)" != "$_channel_2g" ] || 
			[ "$(uci -q get wireless.mesh2_sta.bssid)" != "$_bssid_2g" ]||
			[ "$(uci -q get wireless.mesh2_sta.disabled)" != "0" ]
		then
			uci set wireless.mesh2_sta.bssid="$_bssid_2g"
			uci set wireless.mesh2_sta.disabled='0'
			[ "$(is_5ghz_capable)" == "1" ] && uci set wireless.mesh5_sta.disabled='1'

			if set_wifi_local_config "" "" "$_channel_2g" "" "" "" "" "" \
				"" "" "auto" "" "" "" "" "" "$_mesh_mode"
			then
				log "MESHLINK" "Change 2.4Ghz Backbone ($_channel_2g) ($_bssid_2g) ..."
				wifi reload
				sleep 5
				# Atheros stations needs some extra time to connect and prevent a deadloop on backbone probing
				[ -n "$(uci -q get wireless.mesh2_sta.ifname | grep ath )" ] && sleep 15
			else
				log "MESHLINK" "FAIL in change 2.4Ghz Backbone ($_channel_2g) ($_bssid_2g) ..."
			fi
		else
			log "MESHLINK" "Keep 2.4Ghz Backbone ($_channel_2g) ($_bssid_2g) ..."
		fi
	fi

	return 1
}

# Check if Mesh is connected
# ** Should print any non-empty string if mesh is connected **
is_mesh_connected() {
	local _mesh_mode="$(get_mesh_mode)"
	local _mesh_master="$(get_mesh_master)"
	local conn=""
	if [ "$_mesh_mode" -eq "2" ] || [ "$_mesh_mode" -eq "4" ]
	then
		ifconfig $(get_station_ifname 0) &>/dev/null && [ "$(iwinfo $(get_station_ifname 0) assoclist | grep -v "No station connected")" ] && conn="1"
	fi
	if [ "$(is_5ghz_capable)" == "1" ]
	then
		if [ "$_mesh_mode" -eq "3" ] || [ "$_mesh_mode" -eq "4" ]
		then
			ifconfig $(get_station_ifname 1) &>/dev/null && [ "$(iwinfo $(get_station_ifname 1) assoclist | grep -v "No station connected")" ] && conn="1"
		fi
	fi
	echo "$conn"
}

change_fast_transition() {
	local _radio="$1"
	local _enabled="$2"
	# FAST TRANSITION IS DISABLED FOR NOW
	#if [ "$_enabled" = "1" ]
	#then
	#	# Enable Fast Transition
	#	uci set wireless.default_radio$_radio.ieee80211r="1"
	#	uci set wireless.default_radio$_radio.ieee80211v="1"
	#	uci set wireless.default_radio$_radio.bss_transition="1"
	#	uci set wireless.default_radio$_radio.ieee80211k="1"
	#else
	#	uci delete wireless.default_radio$_radio.ieee80211r
	#	uci delete wireless.default_radio$_radio.ieee80211v
	#	uci delete wireless.default_radio$_radio.bss_transition
	#	uci delete wireless.default_radio$_radio.ieee80211k
	#fi
}
