#!/bin/sh

. /usr/share/flashman_init.conf
. /usr/share/functions.sh

CLIENT_MAC=$(get_mac)

# Verify if connection is up.
check_connectivity()
{
  if ping -q -c 2 -W 2 "$FLM_SVADDR"  >/dev/null
  then
    # true
    echo 0
  else
    # false
    echo 1
  fi
}

connected=false
while [ "$connected" != true ]
do
  if [ "$(check_connectivity)" -eq 0 ]
  then
    sh /usr/share/flashman_update.sh now
    connected=true
  fi
  sleep 5
done

sh /usr/share/keepalive.sh &

while true
do
  if [ "$(mosquitto_sub -C 1 -h $FLM_SVADDR -t flashman/update/$CLIENT_MAC)" == "1" ]
  then
    sh /usr/share/flashman_update.sh now
  fi
  sleep 2
done
