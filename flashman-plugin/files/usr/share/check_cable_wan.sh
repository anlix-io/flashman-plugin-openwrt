#!/bin/sh

do_restart=false

reset_leds () {
  for trigger_path in $(ls -d /sys/class/leds/*)       
  do                                                   
    echo "none" > "$trigger_path"/trigger              
    echo "0" > "$trigger_path"/brightness              
  done

  /etc/init.d/led restart >/dev/nul
  #reset lan ports if any
  for lan_led in /sys/class/leds/*lan*
  do
    if [ -f "$lan_led"/enable_hw_mode ]; then
      echo 1 > "$lan_led"/enable_hw_mode
    fi
  done

  #reset system led
  #TODO: blink on flashing firmware?
  for system_led in /sys/class/leds/*system*/brightness
  do                                      
    echo "255" > "$system_led"
  done   

  #reset 5G if any
  if [ -f /sys/class/leds/ath9k-phy1/trigger ]; then
    echo "phy1tpt" > /sys/class/leds/ath9k-phy1/trigger
  fi

  #reset wan if any
  for wan_led in /sys/class/leds/*wan*
  do                                      
    if [ -f "$wan_led"/enable_hw_mode ]; then
      echo 1 > "$wan_led"/enable_hw_mode
    fi
  done
}

while true
do
  wan_itf_name=$(uci get network.wan.ifname)
  is_cable_conn=$(cat /sys/class/net/$wan_itf_name/carrier)

  if [ $is_cable_conn -eq 1 ]
  then
    # We have layer 2 connectivity, now check external access
    if ! ping -q -c 2 -W 2 www.google.com  >/dev/null
    then
      # Blink all LEDs
      for trigger_path in $(ls -d /sys/class/leds/*)
      do
        echo "none" > "$trigger_path"/trigger
        echo "255" > "$trigger_path"/brightness
        echo "timer" > "$trigger_path"/trigger
      done
      do_restart=true
      # TODO: Notify using REST API
    else
      # The device has external access. Cancel notifications
      if "$do_restart"
      then
        reset_leds
        do_restart=false
      fi
      # TODO: Cancel REST notifications
    fi
  else
    # Cable is not connected

    if "$do_restart"
    then
      reset_leds
      do_restart=false
    fi
    # TODO: Notify using REST API
  fi
  sleep 2
done