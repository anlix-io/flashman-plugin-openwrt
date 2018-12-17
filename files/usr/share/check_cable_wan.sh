#!/bin/sh

. /usr/share/functions.sh

do_restart=0

check_connectivity_internet()
{
  if ping -q -c 2 -W 2 www.google.com  >/dev/null
  then
    # true
    echo 0
  else
    # false
    echo 1
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
    echo "none" > "$trigger_path"/trigger
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

  /etc/init.d/led restart >/dev/nul

  case $(cat /tmp/sysinfo/board_name) in
    tl-wr840n-v4 | tl-wr849n-v4 | tl-wr845n-v3 | archer-c20-v4)
      led_on /sys/class/leds/$(cat /tmp/sysinfo/board_name)\:green\:power
      if [ $(cat /tmp/sysinfo/board_name) = "archer-c20-v4" ]
      then
        # bug on archer's lan led
        echo "0" > \
          /sys/class/leds/$(cat /tmp/sysinfo/board_name)\:green\:lan/port_mask
        echo "0x1e" > \
          /sys/class/leds/$(cat /tmp/sysinfo/board_name)\:green\:lan/port_mask
      fi
      ;;
    tl-wr849n-v5 | tl-wr849n-v6)
      led_netdev \
        /sys/class/leds/$(cat /tmp/sysinfo/board_name)\:green\:power eth0.2
      ;;
    dl-dwr116-a3)
      led_on /sys/class/leds/$(cat /tmp/sysinfo/board_name)\:green\:status
      ;;
    tl-wr841n-v7)
      led_on /sys/class/leds/tp-link\:green\:system
      if [ -f /sys/class/leds/ath9k-phy0/trigger ]
      then
        echo "phy1tpt" > /sys/class/leds/ath9k-phy0/trigger
      fi
      ;;
    *)
      for system_led in /sys/class/leds/*system*
      do
        led_on "$system_led"
      done

      #reset hardware lan ports if any
      for lan_led in /sys/class/leds/*lan*
      do
        if [ -f "$lan_led"/enable_hw_mode ]
        then
          echo 1 > "$lan_led"/enable_hw_mode
        fi
      done

      #reset hardware wan port if any
      for wan_led in /sys/class/leds/*wan*
      do
        if [ -f "$wan_led"/enable_hw_mode ]
        then
          echo 1 > "$wan_led"/enable_hw_mode
        fi
      done

      #reset atheros 5G led
      if [ -f /sys/class/leds/ath9k-phy1/trigger ]
      then
        echo "phy1tpt" > /sys/class/leds/ath9k-phy1/trigger
      fi
      ;;
  esac

  do_restart=0
}

blink_leds() {
  if [ $do_restart -eq 0 ]
  then
    case $(cat /tmp/sysinfo/board_name) in
      tl-wr840n-v5 | tl-wr840n-v6 | tl-wr849n-v5 | tl-wr849n-v6)
        led_off /sys/class/leds/$(cat /tmp/sysinfo/board_name)\:green\:power
        ledsoff=/sys/class/leds/$(cat /tmp/sysinfo/board_name)\:orange\:power
        ;;
      tl-wr840n-v4)
        # Need to turn power off to avoid out-of-sync blink
        led_off /sys/class/leds/$(cat /tmp/sysinfo/board_name)\:green\:power
        ledsoff=$(ls -d /sys/class/leds/*)
        ;;
      tl-wr741nd-v4 | tl-wr841n-v8)
        led_off /sys/class/leds/tp-link\:green\:system
        ledsoff=$(ls -d /sys/class/leds/*)
        ;;
      tl-wr940n-v6)
        led_off /sys/class/leds/tp-link\:blue\:wan
        ledsoff=/sys/class/leds/tp-link\:orange\:diag
        ;;
      tl-wr845n-v3 | archer-c20-v4)
        led_off /sys/class/leds/$(cat /tmp/sysinfo/board_name)\:green\:power
        #we cant turn on orange and blue at same time in this model
        ledsoff=$(ls -d /sys/class/leds/*green*)
        ;;
      *)
        ledsoff=$(ls -d /sys/class/leds/*)
        ;;
    esac

    for trigger_path in $ledsoff
    do
      echo "timer" > "$trigger_path"/trigger
    done
  fi
}

reset_leds
while true
do
  wan_itf_name=$(uci get network.wan.ifname)
  if [ -f /sys/class/net/$wan_itf_name/carrier ]
  then
    is_cable_conn=$(cat /sys/class/net/$wan_itf_name/carrier)

    if [ $is_cable_conn -eq 1 ]
    then
      # We have layer 2 connectivity, now check external access
      if [ ! "$(check_connectivity_internet)" -eq 0 ]
      then
        # No external access
        if [ $do_restart -ne 1 ]
        then
          log "CHECK_WAN" "No external access..."
          blink_leds
          do_restart=1
        fi
      else
        # The device has external access. Cancel notifications
        if [ $do_restart -ne 0 ]
        then
          log "CHECK_WAN" "External access restored..."
          reset_leds
        fi
      fi
    else
      # Cable is not connected
      if [ $do_restart -ne 2 ]
      then
        log "CHECK_WAN" "Cable not connected..."
        blink_leds
        do_restart=2
      fi
    fi
  else
    # WAN interface not created yet
    if [ $do_restart -ne 3 ]
    then
      log "CHECK_WAN" "No WAN interface..."
      blink_leds
      do_restart=3
    fi
  fi
  sleep 2
done
