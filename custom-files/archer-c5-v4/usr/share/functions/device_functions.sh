#!/bin/sh

save_wifi_local_config() {
  # Current MT7620 driver has a bug with 2.4 "auto" channel mode
  if [ "$(uci -q get wireless.radio0.channel)" = "auto" ]
  then
    uci set wireless.radio0.channel="6"
  fi
  uci commit wireless
  /usr/bin/uci2dat -d radio0 -f /etc/Wireless/RT2860/RT2860AP.dat > /dev/null
  /usr/bin/uci2dat -d radio1 -f /etc/Wireless/mt76x2e/mt76x2e.dat > /dev/null
}

is_5ghz_capable() {
  # true
  echo "1"
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

  # bug on archer's lan led
  echo "0" > \
    /sys/class/leds/$(cat /tmp/sysinfo/board_name)\:green\:lan/port_mask
  echo "0xf" > \
    /sys/class/leds/$(cat /tmp/sysinfo/board_name)\:green\:lan/port_mask
}

blink_leds() {
	local _do_restart=$1

  if [ $_do_restart -eq 0 ]
  then
    led_off /sys/class/leds/$(cat /tmp/sysinfo/board_name)\:green\:power
    # we cant turn on orange and blue at same time in this model
    ledsoff=$(ls -d /sys/class/leds/*green*)

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
  swconfig dev switch1 port 4 get link | \
  awk '{print $3}' | awk -F: '{print $2}' | awk -Fbase '{print $1}'
}

# Possible values: empty, half or full
get_wan_negotiated_duplex() {
  swconfig dev switch1 port 4 get link | \
  awk '{print $4}' | awk -F- '{print $1}'
}
