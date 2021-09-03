#!/bin/sh

. /usr/share/libubox/jshn.sh
. /usr/share/functions/custom_wireless_driver.sh


# Check if there is station
# Returns:
#	0: None
#	1: Only 2.4G
#	2: Only 5G
#	3: Both 2.4G and 5G
is_station_capable() {
	local _ret=0
	local _ret5=0

	if [ -f /usr/sbin/wpad ]
	then
		local _24iface=$(get_24ghz_phy)
		local _5iface=$(get_5ghz_phy)

		# If it has any vap, so the station exists
		[ "$_24iface" ] && [ "$(get_station_ifname "0")" ] && _ret=1
		[ "$_5iface" ] && [ "$(get_station_ifname "1")" ] && _ret5=1
	fi

	if [ "$_ret5" -eq "1" ]
	then
		[ "$_ret" -eq "1" ] && echo "3" || echo "2"
	else
		echo "$_ret"
	fi
}

# Get Station SSID from configuration file
get_station_ssid() {
	local _station_ssid=""
	json_cleanup
	json_load_file /root/flashbox_config.json
	json_get_var _station_ssid station_ssid
	json_close_object
	[ "$_station_ssid" ] && echo "$_station_ssid" || echo "Anlix-STA"
}

# Get station Key from configuration file
get_station_key() {
	local _station_key=""
	json_cleanup
	json_load_file /root/flashbox_config.json
	json_get_var _station_key station_key
	json_close_object
	[ "$_station_key" ] && echo "$_station_key" || echo "tempkey1234"
}

# Creates the configuration for Station Interface
enable_station() {
	# $1: Station Mode
		# 1: Disable all
		# 2: Enable only 2.4G
		# 3: Enable only 5G
		# 4: Enable all
	# $2: Station SSID 	(if needed)
	# $3: Station Key 	(if needed)

	local _station_mode=$1
	local _new_station_ssid	
	local _new_station_key
	local _do_save=0

	local _local_station_ssid="$(get_station_ssid)"
	local _station_capable=$(is_station_capable)

	# Check if it needs to change the ssid and key
	if [ "$#" -eq 3 ]
	then
		_new_station_ssid="$2"
		_new_station_key="$3"
	else
		_new_station_ssid="$(get_station_ssid)"
		_new_station_key="$(get_station_key)"
	fi

	# Save the config in json
	if [ "$_local_station_ssid" != "$_new_station_ssid" ]
	then
		json_cleanup
		json_load_file /root/flashbox_config.json
		json_add_string mesh_id "$_new_station_ssid"
		json_add_string mesh_key "$_new_station_key"
		json_dump > /root/flashbox_config.json
		json_close_object
	fi

	# Check if it can use Station
	if [ "$_station_capable" -gt "0" ]
	then
		if [ "$_station_mode" -eq "2" ] || [ "$_station_mode" -eq "4" ]
		then
			if [ "$_station_capable" -eq "1" ] || [ "$_station_capable" -eq "3" ]
			then
				# Set the configuration for 2.4G
				uci set wireless.station2=wifi-iface
				uci set wireless.station2.device='radio0'
				uci set wireless.station2.ifname="$(get_station_ifname "0")"
				uci set wireless.station2.mode='sta'
				uci set wireless.station2.ssid="$_new_station_ssid"
				uci set wireless.station2.encryption='psk2+aes'
				uci set wireless.station2.key="$_new_station_key"
				uci set wireless.station2.disabled='0'
				_do_save=1
			fi
		else
			if [ "$(uci -q get wireless.station2)" ]
			then
				# Delete 2.4G Station entry 
				uci delete wireless.station2
				_do_save=1
			fi
		fi

		if [ "$_station_mode" -eq "3" ] || [ "$_station_mode" -eq "4" ]
		then
			if [ "$_station_capable" -eq "2" ] || [ "$_station_capable" -eq "3" ]
			then
				# Set the configuration for 5G
				uci set wireless.station5=wifi-iface
				uci set wireless.station5.device='radio1'
				uci set wireless.station5.ifname="$(get_station_ifname "1")"
				uci set wireless.station5.mode='sta'
				uci set wireless.station5.ssid="$_new_station_ssid"
				uci set wireless.station5.encryption='psk2+aes'
				uci set wireless.station5.key="$_new_station_key"
				uci set wireless.station5.disabled='0'
				_do_save=1
			fi
		else
			if [ "$(uci -q get wireless.station5)" ]
			then
				# Delete 5G Station entry
				uci delete wireless.station5
				_do_save=1
			fi
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