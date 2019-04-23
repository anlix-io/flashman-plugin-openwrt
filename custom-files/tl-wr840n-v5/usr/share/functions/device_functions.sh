#!/bin/sh

save_wifi_local_config() {
  uci commit wireless
  /usr/bin/uci2dat -d radio0 -f /etc/wireless/mt7628/mt7628.dat > /dev/null
}

is_5ghz_capable() {
  # false
  echo "0"
}

get_wifi_device_stats() {
  # TODO Implement this function
  echo "0.0 0.0 0.0 0.0 0 Z"
}

is_device_wireless() {
  # TODO Implement this function
  return 1
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
    led_off /sys/class/leds/$(cat /tmp/sysinfo/board_name)\:green\:power
    ledsoff=/sys/class/leds/$(cat /tmp/sysinfo/board_name)\:orange\:power

    for trigger_path in $ledsoff
    do
      echo "timer" > "$trigger_path"/trigger
    done
  fi
}

get_mac() {
  local _mac_address_tag=""

  if [ ! -z "$(awk '{ print toupper($1) }' /sys/class/net/eth0/address)" ]
  then
    _mac_address_tag=$(awk '{ print toupper($1) }' /sys/class/net/eth0/address)
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
  # TODO Implement this function
  echo "0"
}
