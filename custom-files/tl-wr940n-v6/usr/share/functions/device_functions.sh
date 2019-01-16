#!/bin/sh

save_wifi_local_config() {
  uci commit wireless
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
  if [ -f /sys/class/leds/ath9k-phy1/trigger ]
  then
    echo "phy1tpt" > /sys/class/leds/ath9k-phy1/trigger
  fi
}

blink_leds() {
	local _do_restart=$1

  if [ $_do_restart -eq 0 ]
  then
    led_off /sys/class/leds/tp-link\:blue\:wan
    ledsoff=/sys/class/leds/tp-link\:orange\:diag
    for trigger_path in $ledsoff
    do
      echo "timer" > "$trigger_path"/trigger
    done
  fi
}

get_mac() {
  local _mac_address_tag=""
  local _p0
  _p0=$(awk '{print toupper($1)}' /sys/class/ieee80211/phy0/macaddress)

  if [ ! -z "$_p0" ]
  then
    _mac_address_tag=$_p0
  fi

  echo "$_mac_address_tag"
}
