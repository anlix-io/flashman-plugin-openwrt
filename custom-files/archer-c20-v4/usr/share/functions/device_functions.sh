#!/bin/sh

. /lib/functions.sh
. /lib/functions/leds.sh

get_custom_hardware_model() {
  echo "ARCHERC20"
}

get_custom_hardware_version() {
  echo "V4"
}

get_radio_phy() {
  echo "$(ls /sys/devices/$(uci get wireless.radio$1.path)/ieee80211)"
}

get_phy_type() {
  #1: 2.4 2: 5GHz
  echo "$(iw phy $1 channels|grep Band|cut -c6)"
}

get_24ghz_phy() {
  for i in /sys/class/ieee80211/*
  do
    iface=`basename $i`
    [ "$(get_phy_type $iface)" -eq "1" ] && echo $iface
  done
}

get_5ghz_phy() {
  for i in /sys/class/ieee80211/*
  do
    iface=`basename $i`
    [ "$(get_phy_type $iface)" -eq "2" ] && echo $iface
  done
}

is_5ghz_vht() {
  local _5iface=$(get_5ghz_phy)
  [ "$_5iface" ] && [ "$(iw phy $_5iface info|grep "VHT")" ] && echo "1"
}

is_5ghz_capable() {
  [ "$(get_5ghz_phy)" ] && echo "1" || echo "0"
}

is_mesh_routing_capable() {
  local _ret=0
  local _ret5=0
  local _24iface=$(get_24ghz_phy)
  local _5iface=$(get_5ghz_phy)
  [ "$_24iface" ] && [ "$(iw phy $_24iface info|grep "mesh point")" ] && _ret=1
  [ "$_5iface" ] && [ "$(iw phy $_5iface info|grep "mesh point")" ] && _ret5=1
  if [ "$_ret5" -eq "1" ]
  then
    [ "$_ret" -eq "1" ] && echo "3" || echo "2"
  else
    echo "$_ret"
  fi
}

save_wifi_local_config() {
  if [ "$(is_5ghz_capable)" -eq "1" ]
  then
    if [ ! "$(is_5ghz_vht)" ]
    then
      if [ "$(uci -q get wireless.radio1.htmode)" != "HT40" ] ||
        [ "$(uci -q get wireless.radio1.htmode)" != "HT20" ]
      then
        uci set wireless.radio1.htmode="HT40"
      fi
    fi
    [ "$(uci -q get wireless.radio1.hwmode)" = "11ac" ] && uci set wireless.radio1.hwmode="11a"
  fi
  uci commit wireless
}

get_wifi_device_stats() {
  local _dev_mac="$1"
  local _dev_info
  local _wifi_stats=""
  local _retstatus
  local _cmd_res
  local _wifi_itf="wlan0"
  local _ap_freq="2.4"

  _cmd_res=$(command -v iw)
  _retstatus=$?

  if [ $_retstatus -eq 0 ]
  then
    _dev_info="$(iw dev $_wifi_itf station get $_dev_mac 2> /dev/null)"
    _retstatus=$?

    if [ $_retstatus -ne 0 ]
    then
      _wifi_itf="wlan1"
      _ap_freq="5.0"
      _dev_info="$(iw dev $_wifi_itf station get $_dev_mac 2> /dev/null)"
      _retstatus=$?
    fi

    if [ $_retstatus -eq 0 ]
    then
      local _dev_txbitrate="$(echo "$_dev_info" | grep 'tx bitrate:' | awk '{print $3}')"
      local _dev_rxbitrate="$(echo "$_dev_info" | grep 'rx bitrate:' | awk '{print $3}')"
      local _dev_mcs="$(echo "$_dev_info" | grep 'tx bitrate:' | awk '{print $5}')"
      local _dev_signal="$(echo "$_dev_info" | grep -m1 'signal:' | awk '{print $2}' | awk -F. '{print $1}')"
      local _ap_noise="$(iwinfo $_wifi_itf info | grep 'Noise:' | awk '{print $5}' | awk -F. '{print $1}')"
      local _dev_txbytes="$(echo "$_dev_info" | grep 'tx bytes:' | awk '{print $3}')"
      local _dev_rxbytes="$(echo "$_dev_info" | grep 'rx bytes:' | awk '{print $3}')"
      local _dev_txpackets="$(echo "$_dev_info" | grep 'tx packets:' | awk '{print $3}')"
      local _dev_rxpackets="$(echo "$_dev_info" | grep 'rx packets:' | awk '{print $3}')"

      # Calculate SNR
      local _dev_snr="$(($_dev_signal - $_ap_noise))"

      _wifi_stats="$_dev_txbitrate $_dev_rxbitrate $_dev_signal"
      _wifi_stats="$_wifi_stats $_dev_snr $_ap_freq"

      [ "$_dev_mcs" == "VHT-MCS" ] && _wifi_stats="$_wifi_stats AC" || _wifi_stats="$_wifi_stats N"
      # Traffic data
      _wifi_stats="$_wifi_stats $_dev_txbytes $_dev_rxbytes"
      _wifi_stats="$_wifi_stats $_dev_txpackets $_dev_rxpackets"
      echo "$_wifi_stats"
    else
      echo "0.0 0.0 0.0 0.0 0 Z 0 0 0 0"
    fi
  else
    echo "0.0 0.0 0.0 0.0 0 Z 0 0 0 0"
  fi
}

is_device_wireless() {
  local _dev_mac="$1"
  local _dev_info
  local _retstatus
  local _cmd_res
  local _wifi_itf="wlan0"

  _cmd_res=$(command -v iw)
  _retstatus=$?

  if [ $_retstatus -eq 0 ]
  then
    _dev_info="$(iw dev $_wifi_itf station get $_dev_mac 2> /dev/null)"
    _retstatus=$?

    if [ $_retstatus -ne 0 ]
    then
      _wifi_itf="wlan1"
      _dev_info="$(iw dev $_wifi_itf station get $_dev_mac 2> /dev/null)"
      _retstatus=$?
    fi

    [ $_retstatus -eq 0 ] && return 0 || return 1
  else
    return 1
  fi
}

leds_off() {
  for trigger_path in $(ls -d /sys/class/leds/*)
  do
    led_off "$(basename "$trigger_path")"
  done
}

reset_leds() {
  leds_off
  /etc/init.d/led restart > /dev/null
  led_on "$(get_dt_led running)"
}

blink_leds() {
  if [ $1 -eq 0 ]
  then
    local led_blink="$([ "$(type -t get_custom_leds_blink)" ] &&  get_custom_leds_blink || ls -d /sys/class/leds/*green*)"
    leds_off
    for trigger_path in $led_blink; do
      led_timer "$(basename "$trigger_path")" 500 500
    done
  fi
}

get_mac() {
  local _mac_address_tag=""
  local _p1

  _p1=$(awk '{print toupper($1)}' /sys/class/net/eth0/address)
  [ ! -z "$_p1" ] && _mac_address_tag=$_p1

  echo "$_mac_address_tag"
}

get_vlan_device() {
  parse_get_switch() {
    config_get device $2 device
    config_get vlan $2 vlan
    [ $vlan -eq $1 ] && echo "${device}"
  }
  config_load network
  swt=$(config_foreach "parse_get_switch $1" switch_vlan)
  echo "$swt"
}

get_vlan_ports() {
  local _switch="$(get_vlan_device $1)"
  local _port=$(swconfig dev $_switch vlan $1 get ports)
  echo "$(for i in $_port; do [ "${i:1}" != "t" ] && echo $i; done)"
}

get_wan_negotiated_speed() {
  local _switch="$(get_vlan_device 2)"
  local _port="$(get_vlan_ports 2)"
  echo "$(swconfig dev $_switch port $_port get link|sed -ne 's/.*speed:\([0-9]*\)*.*/\1/p')"
}

get_wan_negotiated_duplex() {
  local _switch="$(get_vlan_device 2)"
  local _port="$(get_vlan_ports 2)"
  echo "$(swconfig dev $_switch port $_port get link|sed -ne 's/.* \([a-z]*\)-duplex*.*/\1/p')"
}

get_lan_dev_negotiated_speed() {
  local _speed="0"
  local _switch="$(get_vlan_device 1)"

  for _port in $(get_vlan_ports 1); do
    local _speed_tmp="$(swconfig dev $_switch port $_port get link|sed -ne 's/.*speed:\([0-9]*\)*.*/\1/p')"
    if [ "$_speed_tmp" != "" ]
    then
      if [ "$_speed" != "0" ]
      then
        [ "$_speed" != "$_speed_tmp" ] && _speed="0"
      else
        # First assignment
        _speed="$_speed_tmp"
      fi
    fi
  done

  echo "$_speed"
}

store_enable_wifi() {
  local _itf_num
  # 0: 2.4GHz 1: 5.0GHz 2: Both
  _itf_num=$1

  wifi down

  if [ "$_itf_num" = "0" ]
  then
    uci set wireless.@wifi-iface[0].disabled="0"
  elif [ "$_itf_num" = "1" ]
  then
    uci set wireless.@wifi-iface[1].disabled="0"
  else
    uci set wireless.@wifi-iface[0].disabled="0"

    [ "$(uci -q get wireless.@wifi-iface[1])" ] && uci set wireless.@wifi-iface[1].disabled="0"
  fi
  save_wifi_local_config
  wifi up
}

store_disable_wifi() {
  local _itf_num
  # 0: 2.4GHz 1: 5.0GHz 2: Both
  _itf_num=$1

  wifi down

  if [ "$_itf_num" = "0" ]
  then
    uci set wireless.@wifi-iface[0].disabled="1"
  elif [ "$_itf_num" = "1" ]
  then
    uci set wireless.@wifi-iface[1].disabled="1"
  else
    uci set wireless.@wifi-iface[0].disabled="1"
    [ "$(uci -q get wireless.@wifi-iface[1])" ] && uci set wireless.@wifi-iface[1].disabled="1"
  fi
  save_wifi_local_config
  wifi up
}

get_wifi_state() {
  local _itf_num
  local _q
  # 0: 2.4GHz 1: 5.0GHz
  _itf_num=$1

  if [ "$_itf_num" = "0" ]
  then
    _q=$(uci -q get wireless.@wifi-iface[0].disabled)
    if [ "$_q" ]
    then
      [ "$(uci get wireless.@wifi-iface[0].disabled)" = "1" ] && echo "0" || echo "1"
    else
      echo "1"
    fi
  elif [ "$_itf_num" = "1" ]
  then
    _q=$(uci -q get wireless.@wifi-iface[1].disabled)
    if [ "$_q" ]
    then
      [ "$(uci get wireless.@wifi-iface[1].disabled)" = "1" ] && echo "0" || echo "1"
    else
      echo "1"
    fi
  fi
}

get_wifi_device_signature() {
  local _dev_mac="$1"
  local _q=""
  _q="$(ubus -S call hostapd.wlan0 get_clients | jsonfilter -e '@.clients["'"$_dev_mac"'"].signature')"
  [ -z "$_q" ] && [ "$(is_5ghz_capable)" -eq "1" ] && _q="$(ubus -S call hostapd.wlan1 get_clients | jsonfilter -e '@.clients["'"$_dev_mac"'"].signature')"
  echo "$_q"
}

needs_reboot_bridge_mode() {
  reboot
}
