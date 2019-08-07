#!/bin/sh

. /usr/share/flashman_init.conf
. /usr/share/libubox/jshn.sh
. /usr/share/functions/device_functions.sh
. /usr/share/functions/common_functions.sh

send_boot_log() {
  local _res
  local _header="X-ANLIX-LOGS: NONE"

  if [ "$1" = "boot" ]
  then
    if [ -e /tmp/clean_boot ]
    then
      _header="X-ANLIX-LOGS: FIRST"
    else
      _header="X-ANLIX-LOGS: BOOT"
    fi
  fi
  if [ "$1" = "live" ]
  then
    _header="X-ANLIX-LOGS: LIVE"
  fi

  _res=$(logread | gzip | curl -s --tlsv1.2 --connect-timeout 5 \
         --retry 1 \
         -H "Content-Type: application/octet-stream" \
         -H "X-ANLIX-ID: $(get_mac)" -H "X-ANLIX-SEC: $FLM_CLIENT_SECRET" \
         -H "$_header"  --data-binary @- "https://$FLM_SVADDR/deviceinfo/logs")

  json_cleanup
  json_load "$_res"
  json_get_var _processed processed
  json_close_object

  return $_processed
}

reset_flashapp_pass() {
  json_cleanup
  json_load_file /root/flashbox_config.json
  json_get_var _flashapp_pass flashapp_pass

  if [ "$_flashapp_pass" != "" ]
  then
    json_add_string flashapp_pass ""
    json_dump > /root/flashbox_config.json
  fi

  json_close_object
}

get_flashapp_pass() {
  json_cleanup
  json_load_file /root/flashbox_config.json
  json_get_var _flashapp_pass flashapp_pass
  json_close_object

  echo "$_flashapp_pass"
}

set_flashapp_pass() {
  json_cleanup
  json_load_file /root/flashbox_config.json
  json_add_string flashapp_pass "$1"
  json_dump > /root/flashbox_config.json
  json_close_object
}

flashbox_ping() {
  local _host="$1"
  local _type="$2"
  local _out="$3"
  local _result=$(ping -q -i 0.01 -c 100 "$_host")
  local _latval=$(echo "$_result" | awk -F= 'NR==5 { print $2 }' | \
                  awk -F/ '{ print $2 }')
  local _lossval=$(echo "$_result" | awk -F, 'NR==4 { print $3 }' | \
                   awk '{ print $1 }' | awk -F% '{ print $1 }')

  if [ "$_type" = "lat" ]
  then
    if [ "$_out" = "json" ]
    then
      json_add_object "$_host"
      json_add_string "lat" "$_latval"
      json_close_object
    else
      echo "$_latval"
    fi
  elif [ "$_type" = "loss" ]
  then
    if [ "$_out" = "json" ]
    then
      json_add_object "$_host"
      json_add_string "loss" "$_lossval"
      json_close_object
    else
      echo "$_lossval"
    fi
  else
    if [ "$_out" = "json" ]
    then
      json_add_object "$_host"
      json_add_string "lat" "$_latval"
      json_add_string "loss" "$_lossval"
      json_close_object
    else
      echo "$_latval $_lossval"
    fi
  fi
}

flashbox_multi_ping() {
  local _hosts_file=$1
  local _hosts=""
  local _out=$2
  local _type=$3
  local _result=""
  local _lossval=""
  local _latval=""

  json_cleanup
  json_load_file "$_hosts_file"
  json_select "hosts"
  if [ "$?" -eq 1 ]
  then
    return
  fi
  local _idx="1"
  while json_get_type type "$_idx" && [ "$type" = string ]
  do
    json_get_var _hostaddr "$((_idx++))"
    _hosts="$_hostaddr"$'\n'"$_hosts"
  done
  json_select ".."
  json_close_object

  json_init
  json_add_object "results"
  # Don't put double quotes on _hosts variable!
  for _host in $_hosts
  do
    flashbox_ping "$_host" "$_type" "json"
  done
  json_close_object
  json_dump > "$_out"
  json_cleanup
}

run_ping_ondemand_test() {
  local _hosts_file="/tmp/hosts_file.json"
  local _out_file="/tmp/ping_result.json"
  local _data="id=$(get_mac)"
  local _url="deviceinfo/get/pinghosts"
  local _res
  local _retstatus
  _res=$(rest_flashman "$_url" "$_data")
  _retstatus=$?

  if [ $_retstatus -eq 0 ]
  then
    json_cleanup
    json_load "$_res"
    json_dump > "$_hosts_file"
    json_close_object
    json_cleanup

    flashbox_multi_ping "$_hosts_file" "$_out_file" "all"
    if [ -f "$_out_file" ]
    then
      _res=""
      _res=$(cat "$_out_file" | curl -s --tlsv1.2 --connect-timeout 5 \
             --retry 1 -H "Content-Type: application/json" \
             -H "X-ANLIX-ID: $(get_mac)" -H "X-ANLIX-SEC: $FLM_CLIENT_SECRET" \
             --data @- "https://$FLM_SVADDR/deviceinfo/receive/pingresult")

      json_load "$_res"
      json_get_var _processed processed
      json_close_object

      rm "$_out_file"

      return $_processed
    else
      return 0
    fi
  fi
  return 0
}

download_binary() {
  local _dfile="$2"
  local _uri="$1/$_dfile"
  local _dest_dir="$3"

  if [ "$#" -eq 3 ]
  then
    mkdir -p "$_dest_dir"
    local _zflag="-z $_dest_dir/$_dfile"

    local _md5_remote_hash=`curl -I -s -w "%{http_code}" \
                           -u routersync:landufrj123 \
                           --tlsv1.2 --connect-timeout 5 --retry 3 "$_uri" \
                           | grep "X-Checksum-Md5" | awk '{ print $2 }'`

    local _curl_code=`curl -k -s -w "%{http_code}" -u routersync:landufrj123 \
                           --tlsv1.2 --connect-timeout 5 --retry 3 \
                           -o "/tmp/$_dfile" "$_zflag" "$_uri"`

    if [ "$_curl_code" = "200" ]
    then
      local _md5_local_hash=$(md5sum /tmp/$_dfile | awk '{ print $1 }')
      # if [ "$_md5_remote_hash" != "$_md5_local_hash" ]
      # then
      #   log "DDOS DETECTION" "No match on MD5 hash"
      #   rm "/tmp/$_dfile"
      #   return 1
      # fi
      mv "/tmp/$_dfile" "$_dest_dir/$_dfile"
      log "DDOS DETECTION" "Downloaded file on $_uri"
      return 0
    else
      log "DDOS DETECTION" "Download error on $_uri"
      if [ "$_curl_code" != "304" ]
      then
        rm "/tmp/$_dfile"
        return 1
      else
        return 0
      fi
    fi
  else
    log "DDOS DETECTION" "Wrong number of arguments"
    return 1
  fi
}

flashbox_detect_ddos() {
  local _t="$1"
  local _out="$2"
  local _sv_address="sueste.land.ufrj.br"
  local _vendor=$(cat /tmp/sysinfo/model | awk '{ print toupper($1) }')
  local _model=$(get_hardware_model | \
           awk -F "/" '{ if($2 != "") { print $1"D"; } else { print $1 } }')
  local _ver=$(get_hardware_version)
  local _filename=$_vendor"_"$_model"_"$_ver".run"
  local _result
  local _retstatus

  if [ $_t -eq 0 ]
  then
    download_binary "https://$_sv_address/binaries" $_filename "/tmp"
    _retstatus=$?
    if [ $_retstatus -eq 1 ]
    then
      log "DDOS DETECTION" "Binary download failed"
      return 1
    fi

    if [ ! -f "/tmp/ddos.data" ]
    then
      echo 0 > "/tmp/ddos.data"
      echo 0 >> "/tmp/ddos.data"
      echo 0 >> "/tmp/ddos.data"
      echo 0 >> "/tmp/ddos.data"
      echo 0 >> "/tmp/ddos.data"
    fi

    chmod a+x /tmp/$_filename
    _result=$(/tmp/$_filename 2>/dev/null)

    echo $_result > /tmp/ddos.swp
    head -n -1 /tmp/ddos.data >> /tmp/ddos.swp
    mv /tmp/ddos.swp /tmp/ddos.data
  fi

  let "_t += 1"
  _result=$(sed "${_t}q;d" /tmp/ddos.data)

  if [ "$_out" = "json" ]
  then
    json_add_object "ddos"
    json_add_string "class" "$_result"
    json_close_object
  else
    echo "$_result"
  fi
  return 0
}
