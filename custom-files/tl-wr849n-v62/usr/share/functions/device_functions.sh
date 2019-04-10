#!/bin/sh

save_wifi_local_config() {
  uci commit wireless
  /usr/bin/uci2dat -d radio0 -f /etc/wireless/mt7628/mt7628.dat > /dev/null
}

is_5ghz_capable() {
  # false
  echo "0"
}

led_power_off() {
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
}

blink_leds() {
  local _do_restart=$1

  if [ $_do_restart -eq 0 ]
  then
    led_power_off /sys/class/leds/$(cat /tmp/sysinfo/board_name)\:orange\:power
    ledsoff=$(ls -d /sys/class/leds/$(cat /tmp/sysinfo/board_name)\:green\:*)

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
