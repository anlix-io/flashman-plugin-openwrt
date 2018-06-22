#!/bin/sh

. /usr/share/flashman_init.conf
. /usr/share/functions.sh

CLIENT_MAC=$(get_mac)
log "IMALIVE" "ROUTER STARTED!"

connected=false
while [ "$connected" != true ]
do
  if [ "$(check_connectivity_flashman)" -eq 0 ]
  then
    log "IMALIVE" "Running update ..."
    sh /usr/share/flashman_update.sh 
    connected=true
  else
    sleep 5
  fi
done

sh /usr/share/keepalive.sh &
MQTTSEC=$(set_mqtt_secret)

log "IMALIVE" "Start main loop"

numbacks=0
while true
do
  MQTTSEC=$(set_mqtt_secret)
  if [ -z $MQTTSEC ]
  then
    log "IMALIVE" "Empty MQTT Secret... Waiting..."
  else
    log "IMALIVE" "Running MQTT client"
    anlix-mqtt flashman/update/$CLIENT_MAC --clientid $CLIENT_MAC --host $FLM_SVADDR --port $MQTT_PORT --cafile /etc/ssl/certs/ca-certificates.crt --shell "sh /usr/share/mqtt.sh " --username $CLIENT_MAC --password $MQTTSEC
    if [ $? -eq 0 ]
    then
      log "IMALIVE" "MQTT Exit OK"
      numbacks=0
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
        log "IMALIVE" "Connected! Running update ..."                                                                                                                                          
        sh /usr/share/flashman_update.sh                                                                                                        
        connected=true          
        numbacks=0                                                                                                                  
      else                                                                                                                                            
        sleep 5
      fi                                                                                                                                       
    done      
  fi

  #backoff
  ran=`head /dev/urandom | tr -dc "0123456789" | head -c2`
  backoff=`expr $numbacks + ( $ran % $numbacks )`
  
  sleep $backoff
  $numbacks=`expr $numbacks + 1`
  if [ "$numbacks" -eq 60 ] 
  then
    numbacks=60
  fi
  log "IMALIVE" "Retrying count $numbacks ..." 
done

