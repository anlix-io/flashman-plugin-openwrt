#!/bin/sh

. /usr/share/flashman_init.conf
. /usr/share/functions/common_functions.sh
. /usr/share/functions/dhcp_functions.sh
. /usr/share/functions/api_functions.sh
. /usr/share/functions/wireless_functions.sh
. /usr/share/functions/data_collecting_functions.sh

case "$1" in
1)
	log "MQTTMSG" "Running Update"
	sh /usr/share/flashman_update.sh $2
	;;
boot)
	log "MQTTMSG" "Rebooting"
	/sbin/reboot
	;;
rstmqtt)
	log "MQTTMSG" "Clean up MQTT secret"
	reset_mqtt_secret
	;;
rstapp)
	log "MQTTMSG" "Clean up APP secret"
	reset_flashapp_pass
	;;
log)
	log "MQTTMSG" "Sending LIVE log "
	send_boot_log "live"
	;;
onlinedev)
	if lock -n /tmp/get_online_devs.lock
	then
		log "MQTTMSG" "Sending Online Devices..."
		send_online_devices
		lock -u /tmp/get_online_devs.lock
	fi
	;;
sitesurvey)
	if lock -n /tmp/get_site_survey.lock
	then
		log "MQTTMSG" "Sending Site Survey..."
		send_site_survey
		lock -u /tmp/get_site_survey.lock
	fi
	;;
ping)
	log "MQTTMSG" "Running ping test"
	run_ping_ondemand_test
	;;
datacollecting)
	log "MQTTMSG" "Changing data collecting settings"
	set_data_collecting_on_off "$2"
	;;
collectlatency)
	log "MQTTMSG" "Changing the collecting of latencies when collecting data"
	set_collect_latency "$2"
	;;
status)
	if lock -n /tmp/get_status.lock
	then
		log "MQTTMSG" "Collecting status information"
		router_status
		lock -u /tmp/get_status.lock
	fi
	;;
wifistate)
	log "MQTTMSG" "Changing wireless radio state"
	change_wifi_state "$2" "$3"
	;;
speedtest)
	if lock -n /tmp/set_speedtest.lock
	then
		log "MQTTMSG" "Starting speed test..."
		run_speed_ondemand_test "$2" "$3" "$4" "$5"
		lock -u /tmp/set_speedtest.lock
	fi
	;;
wps)
	if lock -n /tmp/set_wps.lock
	then
		log "MQTTMSG" "WPS push button pressed"
		set_wps_push_button "$2"
		lock -u /tmp/set_wps.lock
	fi
	;;
*)
	log "MQTTMSG" "Cant recognize message: $1"
	;;
esac

[ "$(type -t anlix_force_clean_memory)" ] && anlix_force_clean_memory
