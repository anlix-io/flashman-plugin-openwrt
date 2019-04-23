#!/bin/sh

save_wifi_local_config() {
  uci commit wireless
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

  led_on /sys/class/leds/$(cat /tmp/sysinfo/board_name)\:green\:status
}

blink_leds() {
	local _do_restart=$1

  if [ $_do_restart -eq 0 ]
  then
    ledsoff=$(ls -d /sys/class/leds/*)
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

# Possible values: empty, 10, 100 or 100
get_wan_negotiated_speed() {
  swconfig dev switch0 port 4 get link | \
  awk '{print $3}' | awk -F: '{print $2}' | awk -Fbase '{print $1}'
}

# Possible values: empty, half or full
get_wan_negotiated_duplex() {
  swconfig dev switch0 port 4 get link | \
  awk '{print $4}' | awk -F- '{print $1}'
}

get_lan_dev_negotiated_speed() {
  local _mac="$1"
  # TODO Implement this function
  echo "0"
}
