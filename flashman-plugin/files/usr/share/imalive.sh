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
MQTTSEC=$(set_mqtt_secret)

while true
do
  anlix-mqtt flashman/update/$CLIENT_MAC --clientid $CLIENT_MAC --host $FLM_SVADDR --port $MQTT_PORT --cafile /etc/ssl/certs/ca-certificates.crt --shell "sh /usr/share/flashman_update.sh now" --username $CLIENT_MAC --password $MQTTSEC

  sleep 2
done
