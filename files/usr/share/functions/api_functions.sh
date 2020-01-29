#!/bin/sh

. /usr/share/flashman_init.conf
. /usr/share/libubox/jshn.sh
. /usr/share/functions/device_functions.sh
. /usr/share/functions/firewall_functions.sh

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

sys_uptime() {
  echo "$(awk -F. '{print $1}' /proc/uptime)"
}

wan_uptime() {
  local _wan_uptime
  local _wan_up

  json_cleanup
  json_load "$(ifstatus wan)"
  json_get_var _wan_up up

  if [ $_wan_up -eq 1 ]
  then
    json_get_var _wan_uptime uptime
  else
    _wan_uptime="0"
  fi

  json_close_object

  echo "$_wan_uptime"
}

router_status() {
  local _res
  local _processed
  local _sys_uptime
  local _wan_uptime
  local _out_file="/tmp/router_status.json"

  _sys_uptime="$(sys_uptime)"
  _wan_uptime="$(wan_uptime)"

  json_init
  json_add_string "sysuptime" "$_sys_uptime"
  json_add_string "wanuptime" "$_wan_uptime"
  json_dump > "$_out_file"
  json_cleanup

  if [ -f "$_out_file" ]
  then
    _res=""
    _res=$(cat "$_out_file" | curl -s --tlsv1.2 --connect-timeout 5 \
           --retry 1 -H "Content-Type: application/json" \
           -H "X-ANLIX-ID: $(get_mac)" -H "X-ANLIX-SEC: $FLM_CLIENT_SECRET" \
           --data @- "https://$FLM_SVADDR/deviceinfo/receive/routerstatus")

    json_load "$_res"
    json_get_var _processed processed
    json_close_object

    rm "$_out_file"

    return $_processed
  else
    return 0
  fi
}

run_speed_ondemand_test() {
  local _sv_ip_addr="$1"
  local _username="$2"
  local _connections="$3"
  local _timeout="$4"
  local _url="http://$_sv_ip_addr/measure"
  local _urllist=""
  local _result
  local _retstatus
  local _reply
  for i in $(seq 1 "$_connections")
  do
    _urllist="$_urllist $_url/file$i.bin"
  done
  log "SPEEDTEST" "Dropping traffic on firewall..."
  drop_all_forward_traffic
  _result="$(flash-measure "$_timeout" "$_connections" $_urllist)"
  _retstatus=$?
  log "SPEEDTEST" "Restoring firewall to normal..."
  undrop_all_forward_traffic
  _reply='{"downSpeed":"'"$_result"'","user":"'"$_username"'"}'
  curl -s --tlsv1.2 --connect-timeout 5 --retry 1 -H "Content-Type: application/json" \
  -H "X-ANLIX-ID: $(get_mac)" -H "X-ANLIX-SEC: $FLM_CLIENT_SECRET" --data "$_reply" \
  "https://$FLM_SVADDR/deviceinfo/receive/speedtestresult"
  return 0
}
