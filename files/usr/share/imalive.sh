#!/bin/sh

. /usr/share/flashman_init.conf
. /usr/share/functions/common_functions.sh
. /usr/share/functions/system_functions.sh
. /usr/share/functions/device_functions.sh
. /usr/share/functions/network_functions.sh
. /usr/share/functions/wireless_functions.sh
. /usr/share/functions/mesh_functions.sh

redo_connections() {
	[ "$(get_mesh_mode)" -gt "1" ] && [ "$(is_mesh_slave)" = "1" ] && [ ! "$(is_mesh_connected)" ] && update_mesh_link
	renew_dhcp
}

_anlix_version="$(cat /etc/anlix_version)"
log "IMALIVE" "ROUTER STARTED (v$_anlix_version)!"

connected=false
_num_ntptests=0
while [ "$connected" != true ]
do
	if [ "$(check_connectivity_flashman)" -eq 0 ]
	then
		ntpinfo=$(ntp_anlix)
		if [ $ntpinfo = "unsync" ]
		then
			log "IMALIVE" "Sync date with Flashman!"
			resync_ntp
			#give some time to sync (just in second attempt)
			if [ $_num_ntptests -eq 0 ]
			then
				_num_ntptests=1
			else
				sleep 5
			fi
		else
			_num_ntptests=0
			log "IMALIVE" "Running update..."
			sh /usr/share/flashman_update.sh
			if [ $? == 1 ]
			then
				connected=true
			else
				sleep 5
			fi
		fi
	else
		log "IMALIVE" "Cant reach Flashman server! Waiting to retry ..."
		sleep 5
		redo_connections
	fi
done

MQTTSEC=$(set_mqtt_secret)

log "IMALIVE" "Start main loop (v$_anlix_version)"

numbacks=1
while true
do
	MQTTSEC=$(set_mqtt_secret)
	if [ -z $MQTTSEC ]
	then
		log "IMALIVE" "Empty MQTT Secret... Waiting..."
	else
		[ "$(type -t anlix_force_clean_memory)" ] && anlix_force_clean_memory
		log "IMALIVE" "Running MQTT client (v$_anlix_version)"
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
	if [ "$(check_connectivity_flashman)" -eq 1 ]
	then
		log "IMALIVE" "Cant reach Flashman server! Waiting to retry ..."
		connected=false
		while [ "$connected" != true ]
		do
			if [ "$(check_connectivity_flashman)" -eq 0 ]
			then
				log "IMALIVE" "Running update..."
				sh /usr/share/flashman_update.sh
				if [ $? == 1 ]
				then
					connected=true
					numbacks=1
				else
					sleep 5
				fi
			else
				sleep 5
				redo_connections
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
