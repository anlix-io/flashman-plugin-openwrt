#!/bin/sh

. /usr/share/libubox/jshn.sh
. /usr/share/functions/device_functions.sh

get_online_devices() {
  local _dhcp_macs=$(awk '{ print $2 }' /tmp/dhcp.leases)
  local _dhcp_ips=$(awk '{ print $3 }' /tmp/dhcp.leases)
  local _dhcp_names=$(awk '{ if ($4=="*") print "!"; else print $4 }' \
                      /tmp/dhcp.leases)
  json_init
  json_add_object "Devices"
  local _idx=1
  for _mac in $_dhcp_macs
  do
    json_add_object "$_mac"
    json_add_string "ip" "$(echo $_dhcp_ips | awk -v N=$_idx '{ print $N }')"
    json_add_string "hostname" "$(echo $_dhcp_names | awk -v N=$_idx '{ print $N }')"
    json_close_object
    _idx=$((_idx+1))
  done
  json_close_object
  json_dump
}

send_online_devices() {
  local _res
  _res=$(get_online_devices | curl -s --tlsv1.2 --connect-timeout 5 \
         --retry 1 -H "Content-Type: application/json" \
         -H "X-ANLIX-ID: $(get_mac)" \
         -H "X-ANLIX-SEC: $FLM_CLIENT_SECRET" \
         --data @- "https://$FLM_SVADDR/deviceinfo/receive/devices")
  json_cleanup
  json_load "$_res"
  json_get_var _processed processed
  json_close_object

  return $_processed
}
