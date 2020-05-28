#!/bin/sh

. /usr/share/libubox/jshn.sh
. /usr/share/functions/device_functions.sh

get_wifi_local_config() {
  local _ssid_24="$(uci -q get wireless.@wifi-iface[0].ssid)"
  local _password_24="$(uci -q get wireless.@wifi-iface[0].key)"
  local _channel_24="$(uci -q get wireless.radio0.channel)"
  local _hwmode_24="$(uci -q get wireless.radio0.hwmode)"
  local _htmode_24="$(uci -q get wireless.radio0.htmode)"
  local _state_24="$(get_wifi_state '0')"

  local _is_5ghz_capable="$(is_5ghz_capable)"
  local _ssid_50="$(uci -q get wireless.@wifi-iface[1].ssid)"
  local _password_50="$(uci -q get wireless.@wifi-iface[1].key)"
  local _channel_50="$(uci -q get wireless.radio1.channel)"
  local _hwmode_50="$(uci -q get wireless.radio1.hwmode)"
  local _htmode_50="$(uci -q get wireless.radio1.htmode)"
  local _state_50="$(get_wifi_state '1')"

  json_cleanup
  json_load "{}"
  json_add_string "local_ssid_24" "$_ssid_24"
  json_add_string "local_password_24" "$_password_24"
  json_add_string "local_channel_24" "$_channel_24"
  json_add_string "local_hwmode_24" "$_hwmode_24"
  json_add_string "local_htmode_24" "$_htmode_24"
  json_add_string "local_state_24" "$_state_24"
  json_add_string "local_5ghz_capable" "$_is_5ghz_capable"
  json_add_string "local_ssid_50" "$_ssid_50"
  json_add_string "local_password_50" "$_password_50"
  json_add_string "local_channel_50" "$_channel_50"
  json_add_string "local_hwmode_50" "$_hwmode_50"
  json_add_string "local_htmode_50" "$_htmode_50"
  json_add_string "local_state_50" "$_state_50"
  echo "$(json_dump)"
  json_close_object
}

set_wifi_local_config() {
  local _do_reload=0

  local _remote_ssid_24="$1"
  local _remote_password_24="$2"
  local _remote_channel_24="$3"
  local _remote_hwmode_24="$4"
  local _remote_htmode_24="$5"
  local _remote_state_24="$6"

  local _remote_ssid_50="$7"
  local _remote_password_50="$8"
  local _remote_channel_50="$9"
  local _remote_hwmode_50="$10"
  local _remote_htmode_50="$11"
  local _remote_state_50="$12"

  json_cleanup
  json_load "$(get_wifi_local_config)"
  json_get_var _local_ssid_24 local_ssid_24
  json_get_var _local_password_24 local_password_24
  json_get_var _local_channel_24 local_channel_24
  json_get_var _local_hwmode_24 local_hwmode_24
  json_get_var _local_htmode_24 local_htmode_24
  json_get_var _local_state_24 local_state_24

  json_get_var _local_ssid_50 local_ssid_50
  json_get_var _local_password_50 local_password_50
  json_get_var _local_channel_50 local_channel_50
  json_get_var _local_hwmode_50 local_hwmode_50
  json_get_var _local_htmode_50 local_htmode_50
  json_get_var _local_state_50 local_state_50
  json_close_object

  if [ "$_remote_ssid_24" != "" ] && \
     [ "$_remote_ssid_24" != "$_local_ssid_24" ]
  then
    uci set wireless.@wifi-iface[0].ssid="$_remote_ssid_24"
    _do_reload=1
  fi
  if [ "$_remote_password_24" != "" ] && \
     [ "$_remote_password_24" != "$_local_password_24" ]
  then
    uci set wireless.@wifi-iface[0].key="$_remote_password_24"
    _do_reload=1
  fi
  if [ "$_remote_channel_24" != "" ] && \
     [ "$_remote_channel_24" != "$_local_channel_24" ]
  then
    uci set wireless.radio0.channel="$_remote_channel_24"
    _do_reload=1
  fi
  if [ "$_remote_hwmode_24" != "" ] && \
     [ "$_remote_hwmode_24" != "$_local_hwmode_24" ]
  then
    if [ "$_remote_hwmode_24" = "11n" ]
    then
      uci set wireless.radio0.hwmode="$_remote_hwmode_24"
      uci set wireless.radio0.wifimode="9"
    elif [ "$_remote_hwmode_24" = "11g" ]
    then
      uci set wireless.radio0.hwmode="$_remote_hwmode_24"
      uci set wireless.radio0.wifimode="4"
    fi
    _do_reload=1
  fi
  if [ "$_remote_htmode_24" != "" ] && \
     [ "$_remote_htmode_24" != "$_local_htmode_24" ]
  then
    if [ "$_remote_htmode_24" = "HT40" ]
    then
      uci set wireless.radio0.htmode="$_remote_htmode_24"
      uci set wireless.radio0.noscan="1"
      uci set wireless.radio0.ht_bsscoexist="0"
      uci set wireless.radio0.bw="1"
    elif [ "$_remote_htmode_24" = "HT20" ]
    then
      uci set wireless.radio0.htmode="$_remote_htmode_24"
      uci set wireless.radio0.noscan="0"
      uci set wireless.radio0.ht_bsscoexist="1"
      uci set wireless.radio0.bw="0"
    fi
    _do_reload=1
  fi

  if [ "$_remote_state_24" != "" ] && \
     [ "$_remote_state_24" = "0" ] && \
     [ "$_local_state_24" = "1" ]
  then
    save_wifi_local_config
    store_disable_wifi "0"
    _do_reload=0
  elif [ "$_remote_state_24" != "" ] && \
       [ "$_remote_state_24" = "1" ] && \
       [ "$_local_state_24" = "0" ]
  then
    save_wifi_local_config
    store_enable_wifi "0"
    _do_reload=0
  fi

  # 5GHz
  if [ "$(uci -q get wireless.@wifi-iface[1])" ]
  then
    if [ "$_remote_ssid_50" != "" ] && \
       [ "$_remote_ssid_50" != "$_local_ssid_50" ]
    then
      uci set wireless.@wifi-iface[1].ssid="$_remote_ssid_50"
      _do_reload=1
    fi
    if [ "$_remote_password_50" != "" ] && \
       [ "$_remote_password_50" != "$_local_password_50" ]
    then
      uci set wireless.@wifi-iface[1].key="$_remote_password_50"
      _do_reload=1
    fi
    if [ "$_remote_channel_50" != "" ] && \
       [ "$_remote_channel_50" != "$_local_channel_50" ]
    then
      uci set wireless.radio1.channel="$_remote_channel_50"
      _do_reload=1
    fi
    if [ "$_remote_hwmode_50" != "" ] && \
       [ "$_remote_hwmode_50" != "$_local_hwmode_50" ]
    then
      if [ "$_remote_hwmode_50" = "11ac" ]
      then
        uci set wireless.radio1.hwmode="$_remote_hwmode_50"
        uci set wireless.radio1.wifimode="15"
      elif [ "$_remote_hwmode_50" = "11na" ]
      then
        uci set wireless.radio1.hwmode="$_remote_hwmode_50"
        uci set wireless.radio1.wifimode="11"
      fi
      _do_reload=1
    fi
    if [ "$_remote_htmode_50" != "" ] && \
       [ "$_remote_htmode_50" != "$_local_htmode_50" ]
    then
      if [ "$_remote_htmode_50" = "VHT80" ]
      then
        uci set wireless.radio1.htmode="$_remote_htmode_50"
        uci set wireless.radio1.noscan="1"
        uci set wireless.radio1.ht_bsscoexist="0"
        uci set wireless.radio1.bw="2"
      elif [ "$_remote_htmode_50" = "VHT40" ]
      then
        uci set wireless.radio1.htmode="$_remote_htmode_50"
        uci set wireless.radio1.noscan="1"
        uci set wireless.radio1.ht_bsscoexist="0"
        uci set wireless.radio1.bw="1"
      elif [ "$_remote_htmode_50" = "HT40" ]
      then
        uci set wireless.radio1.htmode="$_remote_htmode_50"
        uci set wireless.radio1.noscan="1"
        uci set wireless.radio1.ht_bsscoexist="0"
        uci set wireless.radio1.bw="1"
      elif [ "$_remote_htmode_50" = "VHT20" ]
      then
        uci set wireless.radio1.htmode="$_remote_htmode_50"
        uci set wireless.radio1.noscan="0"
        uci set wireless.radio1.ht_bsscoexist="1"
        uci set wireless.radio1.bw="0"
      elif [ "$_remote_htmode_50" = "HT20" ]
      then
        uci set wireless.radio1.htmode="$_remote_htmode_50"
        uci set wireless.radio1.noscan="0"
        uci set wireless.radio1.ht_bsscoexist="1"
        uci set wireless.radio1.bw="0"
      fi
      _do_reload=1
    fi

    if [ "$_remote_state_50" != "" ] && \
       [ "$_remote_state_50" = "0" ] && \
       [ "$_local_state_50" = "1" ]
    then
      save_wifi_local_config
      store_disable_wifi "1"
      _do_reload=0
    elif [ "$_remote_state_50" != "" ] && \
         [ "$_remote_state_50" = "1" ] && \
         [ "$_local_state_50" = "0" ]
    then
      save_wifi_local_config
      store_enable_wifi "1"
      _do_reload=0
    fi
  fi

  if [ $_do_reload -eq 1 ]
  then
    save_wifi_local_config
    wifi reload
  fi
}

change_wifi_state() {
  local _state
  local _itf_num

  _state=$1
  _itf_num=$2

  if [ "_$_state" = "0" ]
  then
    store_disable_wifi "$_itf_num"
  else
    store_enable_wifi "$_itf_num"
  fi
}
