#!/bin/sh

save_wifi_local_config() {
  # This model does not support AC options
  if [ "$(uci -q get wireless.radio1.htmode)" != "HT40" ] ||
     [ "$(uci -q get wireless.radio1.htmode)" != "HT20" ]
  then
    uci set wireless.radio1.htmode="HT40"
  fi
  if [ "$(uci -q get wireless.radio1.hwmode)" != "11na" ]
  then
    uci set wireless.radio1.hwmode="11na"
  fi
  uci commit wireless
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

  # reset atheros 2.4G led
  if [ -f /sys/class/leds/ath9k-phy0/trigger ]
  then
    echo "phy0tpt" > /sys/class/leds/ath9k-phy0/trigger
  fi
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
  local _p1

  _p1=$(awk '{print toupper($1)}' /sys/class/ieee80211/phy1/macaddress)
  if [ ! -z "$_p1" ]
  then
    _mac_address_tag=$_p1
  fi

  echo "$_mac_address_tag"
}

# Possible values: empty, 10, 100 or 100
get_wan_negotiated_speed() {
  swconfig dev switch0 port 1 get link | \
  awk '{print $3}' | awk -F: '{print $2}' | awk -Fbase '{print $1}'
}

# Possible values: empty, half or full
get_wan_negotiated_duplex() {
  swconfig dev switch0 port 1 get link | \
  awk '{print $4}' | awk -F- '{print $1}'
}
