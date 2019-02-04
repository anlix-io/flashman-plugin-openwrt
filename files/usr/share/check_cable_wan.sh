#!/bin/sh

. /usr/share/functions/common_functions.sh
. /usr/share/functions/device_functions.sh

DO_RESTART=0

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
        if [ $DO_RESTART -ne 1 ]
        then
          log "CHECK_WAN" "No external access..."
          blink_leds "$DO_RESTART"
          DO_RESTART=1
        fi
      else
        # The device has external access. Cancel notifications
        if [ $DO_RESTART -ne 0 ]
        then
          log "CHECK_WAN" "External access restored..."
          reset_leds
          DO_RESTART=0
        fi
      fi
    else
      # Cable is not connected
      if [ $DO_RESTART -ne 2 ]
      then
        log "CHECK_WAN" "Cable not connected..."
        blink_leds "$DO_RESTART"
        DO_RESTART=2
      fi
    fi
  else
    # WAN interface not created yet
    if [ $DO_RESTART -ne 3 ]
    then
      log "CHECK_WAN" "No WAN interface..."
      blink_leds "$DO_RESTART"
      DO_RESTART=3
    fi
  fi
  sleep 2
done
