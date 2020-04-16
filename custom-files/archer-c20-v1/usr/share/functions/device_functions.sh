#!/bin/sh

. /lib/functions/system.sh

get_custom_hardware_model() {
  # model file outputs "TP-Link Archer C20 v1"
  echo "$(cat /tmp/sysinfo/model | awk '{ print toupper($2)$3 }')"
}

get_custom_hardware_version() {
  # model file outputs "TP-Link Archer C20 v1"
  echo "$(cat /tmp/sysinfo/model | awk '{ print toupper($4) }')"
}

save_wifi_local_config() {
  uci commit wireless
  /usr/bin/uci2dat -d radio0 -f /etc/Wireless/mt7620/mt7620.dat > /dev/null
  /usr/bin/uci2dat -d radio1 -f /etc/Wireless/iNIC/iNIC_ap.dat > /dev/null
}

is_5ghz_capable() {
  # true
  echo "1"
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

    # 5 GHz search
    _wifi_itf="rai0"
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
          _ap_freq="5.0"
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
      local _dev_txbytes="$(echo "$_dev_info" | grep 'TxBytes:' | \
                            awk '{print $2}')"
      local _dev_rxbytes="$(echo "$_dev_info" | grep 'RxBytes:' | \
                            awk '{print $2}')"
      local _dev_txpackets="$(echo "$_dev_info" | grep 'TxPackets:' | \
                              awk '{print $2}')"
      local _dev_rxpackets="$(echo "$_dev_info" | grep 'RxPackets:' | \
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

    # 5 GHz search
    _wifi_itf="rai0"
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
  for trigger_path in $(ls -d /sys/class/leds/*blue*)
  do
    led_off "$trigger_path"
  done

  /etc/init.d/led restart > /dev/null

  led_on /sys/class/leds/c20-v1\:blue\:power
  # bug on archer's lan led
  echo "0" > \
    /sys/class/leds/c20-v1\:blue\:lan/port_mask
  echo "0x1e" > \
    /sys/class/leds/c20-v1\:blue\:lan/port_mask
}

blink_leds() {
	local _do_restart=$1

  if [ $_do_restart -eq 0 ]
  then
    led_off /sys/class/leds/c20-v1\:blue\:power
    # we cant turn on orange and blue at same time in this model
    ledsoff=$(ls -d /sys/class/leds/*blue*)

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
  local _speed="0"
  local _switch="switch0"
  local _vlan="1"
  local _retstatus

  for _port in $(swconfig dev $_switch vlan $_vlan get ports)
  do
    # Check if it's not a bridge port
    echo "$_port" | grep -q "t"
    _retstatus=$?
    if [ $_retstatus -eq 1 ]
    then
      local _speed_tmp="$(swconfig dev $_switch port $_port get link | \
                          awk -F: '{print $4}' | awk -F 'baseT' '{print $1}')"
      if [ "$_speed_tmp" != "" ]
      then
        if [ "$_speed" != "0" ]
        then
          if [ "$_speed" != "$_speed_tmp" ]
          then
            # Different values. Return 0 since we cannot know the correct value
            _speed="0"
          fi
        else
          # First assignment
          _speed="$_speed_tmp"
        fi
      fi
    fi
  done

  echo "$_speed"
}

store_enable_wifi() {
  local _itf_num
  local _lowermac
  local _lowermac_5
  # 0: 2.4GHz 1: 5.0GHz 2: Both
  _itf_num=$1
  _lowermac=$(get_mac | awk '{ print tolower($1) }')
  _lowermac_5=$(macaddr_add "$_lowermac" 2)

  wifi down

  if [ "$_itf_num" = "0" ]
  then
    insmod /lib/modules/`uname -r`/mt76x2ap.ko
    echo "mt76x2ap" > /etc/modules.d/50-mt76x2
  elif [ "$_itf_num" = "1" ]
  then
    insmod /lib/modules/`uname -r`/mt7610e.ko mac=$_lowermac_5
    echo "mt7610e mac=$_lowermac_5" > /etc/modules.d/51-mt7610e
  else
    insmod /lib/modules/`uname -r`/mt76x2ap.ko
    insmod /lib/modules/`uname -r`/mt7610e.ko mac=$_lowermac_5
    echo "mt76x2ap" > /etc/modules.d/50-mt76x2
    echo "mt7610e mac=$_lowermac_5" > /etc/modules.d/51-mt7610e
  fi

  wifi up
}

store_disable_wifi() {
  local _itf_num
  # 0: 2.4GHz 1: 5.0GHz 2: Both
  _itf_num=$1

  wifi down

  if [ "$_itf_num" = "0" ]
  then
    rmmod /lib/modules/`uname -r`/mt76x2ap.ko
    rm /etc/modules.d/50-mt76x2
  elif [ "$_itf_num" = "1" ]
  then
    rmmod /lib/modules/`uname -r`/mt7610e.ko
    rm /etc/modules.d/51-mt7610e
  else
    rmmod /lib/modules/`uname -r`/mt76x2ap.ko
    rmmod /lib/modules/`uname -r`/mt7610e.ko
    rm /etc/modules.d/50-mt76x2
    rm /etc/modules.d/51-mt7610e
  fi

  wifi up
}

get_wifi_state() {
  local _itf_num
  # 0: 2.4GHz 1: 5.0GHz
  _itf_num=$1

  if [ "$_itf_num" = "0" ]
  then
    lsmod | grep -q "mt76x2ap"
    if [ $? -eq 0 ]
    then
      echo "1"
    else
      echo "0"
    fi
  elif [ "$_itf_num" = "1" ]
  then
    lsmod | grep -q "mt7610e"
    if [ $? -eq 0 ]
    then
      echo "1"
    else
      echo "0"
    fi
  fi
}
