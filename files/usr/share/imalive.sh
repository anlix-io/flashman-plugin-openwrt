#!/bin/sh

. /usr/share/flashman_init.conf
. /usr/share/functions/common_functions.sh
. /usr/share/functions/system_functions.sh
. /usr/share/functions/device_functions.sh
. /usr/share/functions/zabbix_functions.sh

# Verify if connection is up.
check_connectivity_flashman() {
  if ping -q -c 2 -w 2 "$FLM_SVADDR"  >/dev/null
  then
    # true
    echo 0
  else
    # false
    echo 1
  fi
}

log "IMALIVE" "ROUTER STARTED!"

connected=false
_num_ntptests=0
while [ "$connected" != true ]
do
  if [ "$(check_connectivity_flashman)" -eq 0 ]
  then
    ntpinfo=$(ntp_anlix)
    if [ $ntpinfo = "unsync" ]
    then
      log "IMALIVE" "Waiting for NTP to sync! ..."
      _num_ntptests=$(( _num_ntptests + 1 ))
      if [ $_num_ntptests -gt 30 ]
      then
        #More than 30 checks (>150s), force a date update
        log "IMALIVE" "Try resync date with Flashman!"
        resync_ntp
      else
        sleep 5
      fi
    else
      log "IMALIVE" "Connected!"
      log "IMALIVE" "Checking zabbix..."
      check_zabbix_startup "false"
      log "IMALIVE" "Running update..."
      sh /usr/share/flashman_update.sh
      connected=true
    fi
  else
    log "IMALIVE" "No access to internet! Waiting to retry ..."
    sleep 5
  fi
done

MQTTSEC=$(set_mqtt_secret)

log "IMALIVE" "Start main loop"

numbacks=1
while true
do
  MQTTSEC=$(set_mqtt_secret)
  if [ -z $MQTTSEC ]
  then
    log "IMALIVE" "Empty MQTT Secret... Waiting..."
  else
    log "IMALIVE" "Running MQTT client"
    anlix-mqtt flashman/update/$(get_mac) --clientid $(get_mac) \
    --host $FLM_SVADDR --port $MQTT_PORT \
    --cafile /etc/ssl/certs/ca-certificates.crt \
    --shell "sh /usr/share/mqtt.sh " --username $(get_mac) --password $MQTTSEC
    if [ $? -eq 0 ]
    then
      log "IMALIVE" "MQTT Exit OK"
      numbacks=1
    else
      log "IMALIVE" "MQTT Exit with code $?"
    fi
  fi

  #if we were disconnected because of lack of connectivity
  # try again only when connection is restored
  if [ ! "$(check_connectivity_flashman)" -eq 0 ]
  then
    log "IMALIVE" "Cant reach Flashman server!"
    connected=false
    while [ "$connected" != true ]
    do
      if [ "$(check_connectivity_flashman)" -eq 0 ]
      then
        log "IMALIVE" "Reconnected!"
        log "IMALIVE" "Checking zabbix..."
        check_zabbix_startup "true"
        log "IMALIVE" "Running update..."
        sh /usr/share/flashman_update.sh
        connected=true
        numbacks=1
      else
        sleep 5
      fi
    done
  fi

  #backoff
  _rand=$(head /dev/urandom | tr -dc "123456789")
  ran=${_rand:0:2}
  backoff=$(( numbacks + ( ran % numbacks ) ))

  sleep $backoff
  numbacks=$(( numbacks + 1 ))
  if [ $numbacks -gt 60 ]
  then
    numbacks=60
  fi
  log "IMALIVE" "Retrying count $numbacks ..."
done
