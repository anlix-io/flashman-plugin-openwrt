#!/bin/sh

. /usr/share/functions/network_functions.sh

while true
do
  # Collect and store wan traffic information
  store_wan_bytes

  sleep 60
done
