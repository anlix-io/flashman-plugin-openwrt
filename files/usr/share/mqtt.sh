#!/bin/sh

. /usr/share/flashman_init.conf
. /usr/share/functions/common_functions.sh
. /usr/share/functions/dhcp_functions.sh
. /usr/share/functions/api_functions.sh
. /usr/share/functions/zabbix_functions.sh

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
  log "MQTTMSG" "Sending Online Devices..."
  send_online_devices
  ;;
ping)
  log "MQTTMSG" "Running ping test"
  run_ping_ondemand_test
  ;;
measure)
  log "MQTTMSG" "Changing Zabbix PSK settings"
  if [ "$ZBX_SUPPORT" == "y" ]
  then
    update_zabbix_params "$2"
  fi
  ;;
*)
  log "MQTTMSG" "Cant recognize message: $1"
  ;;
esac

