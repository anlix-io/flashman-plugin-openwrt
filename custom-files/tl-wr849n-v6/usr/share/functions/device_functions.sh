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
  local _dev_mac="$1"
  local _dev_num
  local _idx
  local _dev_info=""
  local _retstatus
  local _cmd_res
  local _wifi_itf="ra0"
  local _wifi_stats=""
  local _ap_freq="2.4"

  _cmd_res=$(command -v iwpriv)
  _retstatus=$?

  if [ $_retstatus -eq 0 ]
  then
    _dev_num="$(iwpriv $_wifi_itf assoclist_num 2> /dev/null)"
    _retstatus=$?
    if [ $_retstatus -eq 0 ]
    then
      # Interface returned successfully
      _dev_num="$(echo $_dev_num | awk -F: '{print $2}')"
      for _idx in $(seq 1 $_dev_num)
      do
        iwpriv $_wifi_itf assoclist $_idx | grep $_dev_mac > /dev/null
        _retstatus=$?
        if [ $_retstatus -eq 0 ]
        then
          _dev_info="$(iwpriv $_wifi_itf assoclist $_idx)"
          break
        fi
      done
    fi

    if [ "$_dev_info" != "" ]
    then
      local _dev_txbitrate="$(echo "$_dev_info" | grep 'tx bitrate:' | \
                              awk '{print $3}')"
      local _dev_rxbitrate="0.0"
      local _dev_mode="$(echo "$_dev_info" | grep 'caps:' | \
                         awk '{print $2}')"
      local _dev_signal="$(echo "$_dev_info" | grep 'RSSI:' | \
                           awk '{print $2}')"
      local _dev_snr="$(echo "$_dev_info" | grep 'SNR:' | \
                        awk '{print $2}')"

      _wifi_stats="$_dev_txbitrate $_dev_rxbitrate $_dev_signal"
      _wifi_stats="$_wifi_stats $_dev_snr $_ap_freq"

      if [ "$_dev_mode" == "VHT" ]
      then
        # AC
        _wifi_stats="$_wifi_stats AC"
      elif [ "$_dev_mode" == "HT" ]
      then
        # N
        _wifi_stats="$_wifi_stats N"
      else
        # G
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
  local _dev_num
  local _idx
  local _dev_info
  local _retstatus
  local _cmd_res
  local _wifi_itf="ra0"

  _cmd_res=$(command -v iwpriv)
  _retstatus=$?

  if [ $_retstatus -eq 0 ]
  then
    _dev_info="$(iwpriv $_wifi_itf assoclist_num 2> /dev/null)"
    _retstatus=$?
    if [ $_retstatus -eq 0 ]
    then
      # Interface returned successfully
      _dev_num="$(echo $_dev_info | awk -F: '{print $2}')"
      for _idx in $(seq 1 $_dev_num)
      do
        _dev_info="$(iwpriv $_wifi_itf assoclist $_idx | grep $_dev_mac)"
        _retstatus=$?
        if [ $_retstatus -eq 0 ]
        then
          return 0
        fi
      done
    fi

    # Not found
    return 1
  else
    return 1
  fi
}

led_off() {
  if [ -f "$1"/trigger ]
  then
    echo "none" > "$1"/trigger
    echo "0" > "$1"/brightness
  fi
}

led_netdev() {
  echo "netdev" > "$1"/trigger
  echo "link tx rx" > "$1"/mode
  echo "$2" > "$1"/device_name
}

reset_leds() {
  for trigger_path in $(ls -d /sys/class/leds/*)
  do
    led_off "$trigger_path"
  done

  /etc/init.d/led restart > /dev/null

  led_netdev \
    /sys/class/leds/$(cat /tmp/sysinfo/board_name)\:green\:power eth0.2
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
