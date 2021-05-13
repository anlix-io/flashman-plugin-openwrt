#!/bin/sh

. /usr/share/flashman_init.conf
. /usr/share/libubox/jshn.sh
. /usr/share/functions/common_functions.sh
. /usr/share/functions/device_functions.sh
. /usr/share/functions/network_functions.sh

clean_memory() {
	[ -d /tmp/opkg-lists/ ] && rm -r /tmp/opkg-lists/
	echo 3 > /proc/sys/vm/drop_caches
}

lupg() {
	log "FLASHBOX UPGRADE" "$1"
}

download_file() {
	local _dfile="$2"
	local _uri="$1/$_dfile"
	local _dest_dir="$3"

	if [ "$#" -eq 3 ]
	then
		mkdir -p "$_dest_dir"

		local _md5_remote_hash=`curl -I -s -w "%{http_code}" \
								-u routersync:landufrj123 \
								--tlsv1.2 --connect-timeout 5 --retry 3 "$_uri" \
								| grep "X-Checksum-Md5" | awk '{ print $2 }'`
		if [ ! -f $_dest_dir/$_dfile ]
		then
			local _curl_code=`curl -s -w "%{http_code}" -u routersync:landufrj123 \
								--tlsv1.2 --connect-timeout 5 --retry 3 \
								-o "$_dest_dir/$_dfile" "$_uri"`
			if [ "$_curl_code" != "200" ]
			then
				lupg "FAIL: Download error on $_uri"
				if [ "$_curl_code" != "304" ]
				then
					rm "$_dest_dir/$_dfile"
					return 1
				fi
			fi
		fi

		local _md5_local_hash=$(md5sum $_dest_dir/$_dfile | awk '{ print $1 }')
		if [ "$_md5_remote_hash" != "$_md5_local_hash" ]
		then
			lupg "FAIL: No match on MD5 hash"
			rm "$_dest_dir/$_dfile"
			return 1
		fi
		lupg "Downloaded file on $_uri"
		return 0
	else
		lupg "FAIL: Wrong number of arguments in download"
		return 1
	fi
}

# Downloads correct image based on current model
get_image() {
	if [ "$#" -eq 4 ]
	then
		local _release_id=$1
		local _vendor=$2
		local _model=$3
		local _ver=$4
		local _retstatus
		download_file "https://$FLM_SVADDR/firmwares" \
			$_vendor"_"$_model"_"$_ver"_"$_release_id".bin" "/tmp"
		_retstatus=$?

		if [ $_retstatus -eq 1 ]
		then
			lupg "FAIL: Image download failed"
			return 1
		fi
	else
		lupg "FAIL: Error in number of args for get_image"
		return 1
	fi
	return 0
}

run_reflash() {
	if [ "$#" -eq 1 ]
	then
		lupg "Init image reflash"
		local _release_id=$1
		local _vendor
		local _model
		local _ver
		local _res
		local _pppoe_user_local
		local _pppoe_password_local
		local _connection_type
		_vendor=$(cat /tmp/sysinfo/model | awk '{ print toupper($1) }')
		_model=$(get_hardware_model | \
						awk -F "/" '{ if($2 != "") { print $1"D"; } else { print $1 } }')
		_ver=$(get_hardware_version)
		_pppoe_user_local=$(uci -q get network.wan.username)
		_pppoe_password_local=$(uci -q get network.wan.password)
		_connection_type=$(get_wan_type)

		if ! lock -n /tmp/lock_firmware 2> /dev/null
		then
			lupg "FAIL: Firmware locked!"
			return 1
		fi

		clean_memory
		if get_image "$_release_id" "$_vendor" "$_model" "$_ver"
		then
			_res=$(rest_flashman "deviceinfo/ack/" "id=$(get_mac)&status=1")
			if [ "$(jsonfilter -s "$_res" -e '@.proceed')" = "1" ]
			then
				json_cleanup
				json_load_file /root/flashbox_config.json
				json_add_string has_upgraded_version "1"
				if [ "$(get_bridge_mode_status)" != "y" ]
				then
					# Do not write "none" in case of bridge
					json_add_string wan_conn_type "$_connection_type"
				fi
				json_add_string pppoe_user "$_pppoe_user_local"
				json_add_string pppoe_pass "$_pppoe_password_local"
				json_dump > /root/flashbox_config.json
				tar -zcf /tmp/config.tar.gz /root/flashbox_config.json /root/vlan_config.json
				json_add_string has_upgraded_version "0"
				json_dump > /root/flashbox_config.json
				json_close_object

				/etc/init.d/check_cable_wan stop
				/etc/init.d/keepalive stop
				/etc/init.d/flashman stop
				/etc/init.d/netstats stop
				/etc/init.d/minisapo stop
				/etc/init.d/miniupnpd stop
				/etc/init.d/uhttpd stop
				wifi down
				/etc/init.d/network stop
				clean_memory
				sysupgrade --force -f /tmp/config.tar.gz \
											"/tmp/"$_vendor"_"$_model"_"$_ver"_"$_release_id".bin"
			else
				lock -u /tmp/lock_firmware
				lupg "CANCEL: Cancel by flashman"
				rm "/tmp/"$_vendor"_"$_model"_"$_ver"_"$_release_id".bin"
			fi
		else
			lock -u /tmp/lock_firmware
			_res=$(rest_flashman "deviceinfo/ack/" "id=$(get_mac)&status=2")
		fi
	else
		lupg "FAIL: Error in number of args"
		return 1
	fi
}
