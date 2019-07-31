#!/bin/sh

. /usr/share/flashman_init.conf
. /usr/share/libubox/jshn.sh
. /usr/share/functions/common_functions.sh
. /usr/share/functions/device_functions.sh
. /usr/share/functions/network_functions.sh

clean_memory() {
  rm -r /tmp/opkg-lists/
  echo 3 > /proc/sys/vm/drop_caches
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

    local _curl_code=`curl -s -w "%{http_code}" -u routersync:landufrj123 \
                           --tlsv1.2 --connect-timeout 5 --retry 3 \
                           -o "/tmp/$_dfile" "$_uri"`

    if [ "$_curl_code" = "200" ]
    then
      local _md5_local_hash=$(md5sum /tmp/$_dfile | awk '{ print $1 }')
      if [ "$_md5_remote_hash" != "$_md5_local_hash" ]
      then
        log "FLASHBOX UPGRADE" "No match on MD5 hash"
        rm "/tmp/$_dfile"
        return 1
      fi
      mv "/tmp/$_dfile" "$_dest_dir/$_dfile"
      log "FLASHBOX UPGRADE" "Downloaded file on $_uri"
      return 0
    else
      log "FLASHBOX UPGRADE" "Download error on $_uri"
      if [ "$_curl_code" != "304" ]
      then
        rm "/tmp/$_dfile"
        return 1
      else
        return 0
      fi
    fi
  else
    log "FLASHBOX UPGRADE" "Wrong number of arguments"
    return 1
  fi
}

# Downloads correct image based on current model
get_image() {
  if [ "$#" -eq 5 ]
  then
    local _sv_address=$1
    local _release_id=$2
    local _vendor=$3
    local _model=$4
    local _ver=$5
    local _retstatus
    download_file "https://$_sv_address/firmwares" \
                  $_vendor"_"$_model"_"$_ver"_"$_release_id".bin" "/tmp"
    _retstatus=$?

    if [ $_retstatus -eq 1 ]
    then
      log "FLASHBOX UPGRADE" "Image download failed"
      return 1
    fi
  else
    log "FLASHBOX UPGRADE" "Error in number of args"
    return 1
  fi
  return 0
}

run_reflash() {
  if [ "$#" -eq 2 ]
  then
    log "FLASHBOX UPGRADE" "Init image reflash"
    local _sv_address=$1
    local _release_id=$2
    local _vendor
    local _model
    local _ver
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

    clean_memory
    if get_image "$_sv_address" "$_release_id" "$_vendor" "$_model" "$_ver"
    then
      json_cleanup
      json_load_file /root/flashbox_config.json
      json_add_string has_upgraded_version "1"
      json_add_string wan_conn_type "$_connection_type"
      json_add_string pppoe_user "$_pppoe_user_local"
      json_add_string pppoe_pass "$_pppoe_password_local"
      json_dump > /root/flashbox_config.json
      tar -zcf /tmp/config.tar.gz \
               /etc/config/wireless /root/flashbox_config.json
      json_add_string has_upgraded_version "0"
      json_dump > /root/flashbox_config.json
      json_close_object
      if sysupgrade -T "/tmp/"$_vendor"_"$_model"_"$_ver"_"$_release_id".bin"
      then
        curl -s -A "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1)" \
             --tlsv1.2 --connect-timeout 5 --retry 0 \
             --data "id=$(get_mac)&status=1" \
             "https://$_sv_address/deviceinfo/ack/"
        sysupgrade -f /tmp/config.tar.gz \
                      "/tmp/"$_vendor"_"$_model"_"$_ver"_"$_release_id".bin"
      else
        curl -s -A "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1)" \
           --tlsv1.2 --connect-timeout 5 --retry 0 \
           --data "id=$(get_mac)&status=0" \
           "https://$_sv_address/deviceinfo/ack/"
        log "FLASHBOX UPGRADE" "Image check failed"
        return 1
      fi
    else
      curl -s -A "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1)" \
           --tlsv1.2 --connect-timeout 5 --retry 0 \
           --data "id=$(get_mac)&status=2" \
           "https://$_sv_address/deviceinfo/ack/"
    fi
  else
    log "FLASHBOX UPGRADE" "Error in number of args"
    return 1
  fi
}
