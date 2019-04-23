#!/bin/sh

save_wifi_local_config() {
  uci commit wireless
}

is_5ghz_capable() {
  # false
  echo "0"
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
      local _dev_txbitrate="$(echo "$_dev_info" | grep 'tx bitrate:' | \
                              awk '{print $3}')"
      local _dev_rxbitrate="$(echo "$_dev_info" | grep 'rx bitrate:' | \
                              awk '{print $3}')"
      local _dev_mcs="$(echo "$_dev_info" | grep 'tx bitrate:' | \
                        awk '{print $5}')"
      local _dev_signal="$(echo "$_dev_info" | grep 'signal:' | \
                           awk '{print $2}' | awk -F. '{print $1}')"
      local _ap_noise="$(iwinfo $_wifi_itf info | grep 'Noise:' | \
                         awk '{print $5}' | awk -F. '{print $1}')"
      # Calculate SNR
      local _dev_snr="$(($_dev_signal - $_ap_noise))"

      _wifi_stats="$_dev_txbitrate $_dev_rxbitrate $_dev_signal"
      _wifi_stats="$_wifi_stats $_dev_snr $_ap_freq"

      if [ "$_dev_mcs" == "MCS" ]
      then
        # N or AC
        _wifi_stats="$_wifi_stats N"
      else
        # G Mode
        _wifi_stats="$_wifi_stats G"
      fi
      echo "$_wifi_stats"
    else
      echo "0.0 0.0 0.0 0.0 0 Z"
    fi
  else
    echo "0.0 0.0 0.0 0.0 0 Z"
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

    if [ $_retstatus -eq 0 ]
    then
      return 0
    else
      return 1
    fi
  else
    return 1
  fi
}

led_on() {
  if [ -f "$1"/brightness ]
  then
    if [ -f "$1"/max_brightness ]
    then
      cat "$1"/max_brightness > "$1"/brightness
    else
      echo "255" > "$1"/brightness
    fi
  fi
}

led_off() {
  if [ -f "$1"/trigger ]
  then
    echo "none" > "$1"/trigger
    echo "0" > "$1"/brightness
  fi
}

reset_leds() {
  for trigger_path in $(ls -d /sys/class/leds/*)
  do
    led_off "$trigger_path"
  done

  /etc/init.d/led restart > /dev/null

  for system_led in /sys/class/leds/*system*
  do
    led_on "$system_led"
  done

  # reset hardware lan ports if any
  for lan_led in /sys/class/leds/*lan*
  do
    if [ -f "$lan_led"/enable_hw_mode ]
    then
      echo 1 > "$lan_led"/enable_hw_mode
    fi
  done

  # reset hardware wan port if any
  for wan_led in /sys/class/leds/*wan*
  do
    if [ -f "$wan_led"/enable_hw_mode ]
    then
      echo 1 > "$wan_led"/enable_hw_mode
    fi
  done

  # reset atheros 5G led
  if [ -f /sys/class/leds/ath9k-phy0/trigger ]
  then
    echo "phy0tpt" > /sys/class/leds/ath9k-phy0/trigger
  fi
}

blink_leds() {
  local _do_restart=$1

  if [ $_do_restart -eq 0 ]
  then
    ledsoff=$(ls -d /sys/class/leds/*)
    for trigger_path in $ledsoff
    do
      led_off "$trigger_path"
      echo "timer" > "$trigger_path"/trigger
    done
  fi
}

get_mac() {
  local _mac_address_tag=""
  local _p0
  local _p1
  _p0=$(awk '{print toupper($1)}' /sys/class/ieee80211/phy0/macaddress)

  if [ ! -d "/sys/class/ieee80211/phy1" ]
  then
    if [ ! -z "$_p0" ]
    then
      _mac_address_tag=$_p0
    fi
  else
    _p1=$(awk '{print toupper($1)}' /sys/class/ieee80211/phy1/macaddress)
    if [ ! -z "$_p1" ]
    then
      _mac_address_tag=$_p1
    fi
  fi
  echo "$_mac_address_tag"
}

# Possible values: empty, 10, 100 or 100
get_wan_negotiated_speed() {
  swconfig dev switch0 port 0 get link | \
  awk '{print $3}' | awk -F: '{print $2}' | awk -Fbase '{print $1}'
}

# Possible values: empty, half or full
get_wan_negotiated_duplex() {
  swconfig dev switch0 port 0 get link | \
  awk '{print $4}' | awk -F- '{print $1}'
}

get_lan_dev_negotiated_speed() {
  local _mac="$1"
  local _swport
  local _speed

  _swport="$(swconfig dev switch0 show | grep $_mac | \
             awk -F: '{print $1}' | awk '{print $2}')"
  _speed="$(swconfig dev switch0 port $_swport get link | \
            awk -F: '{print $4}' | awk -F 'baseT' '{print $1}')"
  echo "$_speed"
}
