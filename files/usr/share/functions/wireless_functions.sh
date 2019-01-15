#!/bin/sh

. /usr/share/libubox/jshn.sh
. /usr/share/functions/device_functions.sh

get_wifi_local_config() {
  local _ssid_24="$(uci -q get wireless.@wifi-iface[0].ssid)"
  local _password_24="$(uci -q get wireless.@wifi-iface[0].key)"
  local _channel_24="$(uci -q get wireless.radio0.channel)"
  local _hwmode_24="$(uci -q get wireless.radio0.hwmode)"
  local _htmode_24="$(uci -q get wireless.radio0.htmode)"

  local _ssid_50="$(uci -q get wireless.@wifi-iface[1].ssid)"
  local _password_50="$(uci -q get wireless.@wifi-iface[1].key)"
  local _channel_50="$(uci -q get wireless.radio1.channel)"
  local _hwmode_50="$(uci -q get wireless.radio1.hwmode)"
  local _htmode_50="$(uci -q get wireless.radio1.htmode)"

  #
  # WARNING! No spaces or tabs inside the following string!
  #
  local _wifi_json="{\
'local_ssid_24':'$_ssid_24',\
'local_password_24':'$_password_24',\
'local_channel_24':'$_channel_24',\
'local_hwmode_24':'$_hwmode_24',\
'local_htmode_24':'$_htmode_24',\
'local_ssid_50':'$_ssid_50',\
'local_password_50':'$_password_50',\
'local_channel_50':'$_channel_50',\
'local_hwmode_50':'$_hwmode_50',\
'local_htmode_50':'$_htmode_50'}"

  echo "$_wifi_json"
}

set_wifi_local_config() {
  local _do_reload=0

  local _remote_ssid_24="$1"
  local _remote_password_24="$2"
  local _remote_channel_24="$3"
  local _remote_hwmode_24="$4"
  local _remote_htmode_24="$5"

  local _remote_ssid_50="$6"
  local _remote_password_50="$7"
  local _remote_channel_50="$8"
  local _remote_hwmode_50="$9"
  local _remote_htmode_50="$10"

  json_cleanup
  json_load $(get_wifi_local_config)
  json_get_var _local_ssid_24 local_ssid_24
  json_get_var _local_password_24 local_password_24
  json_get_var _local_channel_24 local_channel_24
  json_get_var _local_hwmode_24 local_hwmode_24
  json_get_var _local_htmode_24 local_htmode_24

  json_get_var _local_ssid_50 local_ssid_50
  json_get_var _local_password_50 local_password_50
  json_get_var _local_channel_50 local_channel_50
  json_get_var _local_hwmode_50 local_hwmode_50
  json_get_var _local_htmode_50 local_htmode_50
  json_close_object

  if [ "$_remote_ssid_24" != "" ] && \
     [ "$_remote_ssid_24" != "$_local_ssid_24" ]
  then
    uci set wireless.@wifi-iface[0].ssid="$_remote_ssid_24"
    local _do_reload=1
  fi
  if [ "$_remote_password_24" != "" ] && \
     [ "$_remote_password_24" != "$_local_password_24" ]
  then
    uci set wireless.@wifi-iface[0].key="$_remote_password_24"
    local _do_reload=1
  fi
  if [ "$_remote_channel_24" != "" ] && \
     [ "$_remote_channel_24" != "$_local_channel_24" ]
  then
    uci set wireless.radio0.channel="$_remote_channel_24"
    local _do_reload=1
  fi
  if [ "$_remote_hwmode_24" != "" ] && \
     [ "$_remote_hwmode_24" != "$_local_hwmode_24" ]
  then
    uci set wireless.radio0.hwmode="$_remote_hwmode_24"
    local _do_reload=1
  fi
  if [ "$_remote_htmode_24" != "" ] && \
     [ "$_remote_htmode_24" != "$_local_htmode_24" ]
  then
    uci set wireless.radio0.htmode="$_remote_htmode_24"
    local _do_reload=1
  fi

  # 5GHz
  if [ "$(uci -q get wireless.@wifi-iface[1])" ]
  then
    if [ "$_remote_ssid_50" != "" ] && \
       [ "$_remote_ssid_50" != "$_local_ssid_50" ]
    then
      uci set wireless.@wifi-iface[1].ssid="$_remote_ssid_50"
      local _do_reload=1
    fi
    if [ "$_remote_password_50" != "" ] && \
       [ "$_remote_password_50" != "$_local_password_50" ]
    then
      uci set wireless.@wifi-iface[1].key="$_remote_password_50"
      local _do_reload=1
    fi
    if [ "$_remote_channel_50" != "" ] && \
       [ "$_remote_channel_50" != "$_local_channel_50" ]
    then
      uci set wireless.radio1.channel="$_remote_channel_50"
      local _do_reload=1
    fi
    if [ "$_remote_hwmode_50" != "" ] && \
       [ "$_remote_hwmode_50" != "$_local_hwmode_50" ]
    then
      uci set wireless.radio1.hwmode="$_remote_hwmode_50"
      local _do_reload=1
    fi
    if [ "$_remote_htmode_50" != "" ] && \
       [ "$_remote_htmode_50" != "$_local_htmode_50" ]
    then
      uci set wireless.radio1.htmode="$_remote_htmode_50"
      local _do_reload=1
    fi
  fi

  if [ $_do_reload -eq 1 ]
  then
    save_wifi_local_config
    wifi reload
  fi
}
