#!/bin/sh

do_restart=false

while true
do
  wan_itf_name=$(uci get network.wan.ifname)
  is_cable_conn=$(cat /sys/class/net/$wan_itf_name/carrier)

  if [ $is_cable_conn -eq 1 ]
  then
    # We have layer 2 connectivity, now check external access
    if ! ping -q -c 2 -W 2 www.google.com  >/dev/null
    then
      # Change device LEDs. Turn everything ON
      for trigger_path in $(ls -d /sys/class/leds/*)
      do
        echo "none" > "$trigger_path"/trigger
        echo "255" > "$trigger_path"/brightness
      done
      do_restart=true
      # TODO: Notify using REST API
    else
      # The device has external access. Cancel notifications
      if "$do_restart"
      then
        /etc/init.d/led restart
        do_restart=false
        # TODO: Cancel REST notifications
      fi
    fi
  else
    # Cable is not connected

    # The device has external access. Cancel notifications
    if "$do_restart"
    then
      /etc/init.d/led restart
      do_restart=false
    fi
    # TODO: Notify using REST API
    echo "" >/dev/null
  fi
  sleep 1
done