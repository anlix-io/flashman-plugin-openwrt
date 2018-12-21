#!/bin/sh

. /usr/share/flashman_init.conf
. /usr/share/libubox/jshn.sh
. /usr/share/functions/device_functions.sh

send_boot_log() {
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

  local _res=$(logread | gzip | curl -s --tlsv1.2 --connect-timeout 5 \
         --retry 1 \
         -H "Content-Type: application/octet-stream" \
         -H "X-ANLIX-ID: $(get_mac)" -H "X-ANLIX-SEC: $FLM_CLIENT_SECRET" \
         -H "$_header"  --data-binary @- "https://$FLM_SVADDR/deviceinfo/logs")

  json_load "$_res"
  json_get_var _processed processed
  json_close_object

  return $_processed
}

reset_flashapp_pass() {
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
  json_load_file /root/flashbox_config.json
  json_get_var _flashapp_pass flashapp_pass
  json_close_object

  echo "$_flashapp_pass"
}

set_flashapp_pass() {
  json_load_file /root/flashbox_config.json
  json_add_string flashapp_pass "$1"
  json_dump > /root/flashbox_config.json
  json_close_object
}
