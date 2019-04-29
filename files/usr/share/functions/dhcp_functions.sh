#!/bin/sh

. /usr/share/libubox/jshn.sh
. /usr/share/functions/device_functions.sh

get_device_conn_type() {
  local _mac=$1
  local _retstatus

  is_device_wireless "$_mac"
  _retstatus=$?
  if [ $_retstatus -eq 0 ]
  then
    # Wireless
    echo "1"
  else
    local _state=$(cat /proc/net/arp | grep "$_mac" | awk '{print $3}')
    if [ "$_state" == "0x2" ]
    then
      # Wired
      echo "0"
    else
      # Not connected
      echo "2"
    fi
  fi
}

get_online_devices() {
  local _dhcp_macs=$(awk '{ print $2 }' /tmp/dhcp.leases)
  local _dhcp_ips=$(awk '{ print $3 }' /tmp/dhcp.leases)
  local _dhcp_names=$(awk '{ if ($4=="*") print "!"; else print $4 }' \
                      /tmp/dhcp.leases)
  # Flush ARP cache and wait to refresh
  ip neigh flush all > /dev/null

  json_init
  json_add_object "Devices"
  local _idx=1
  for _mac in $_dhcp_macs
  do
    local _ip="$(echo $_dhcp_ips | awk -v N=$_idx '{ print $N }')"

    # Force ARP entry refresh
    ping -q -c 1 -w 1 "$_ip" > /dev/null 2>&1
    # After refresh check if device is connected
    local _status=$(cat /proc/net/arp | grep "$_mac" | awk '{print $3}')
    if [ "$_status" != "0x2" ]
    then
      # Not connected get next device
      continue
    fi

    local _hostname="$(echo $_dhcp_names | awk -v N=$_idx '{ print $N }')"
    local _conn_type="$(get_device_conn_type $_mac)"
    local _conn_speed=""
    local _dev_signal=""
    local _dev_snr=""
    local _dev_freq=""
    local _dev_mode=""

    if [ "$_conn_type" == "0" ]
    then
      # Get speed from LAN ports
      _conn_speed=$(get_lan_dev_negotiated_speed $_mac)
    elif [ "$_conn_type" == "1" ]
    then
      local _wifi_stats="$(get_wifi_device_stats $_mac)"
      # Get wireless bitrate
      _conn_speed=$(echo $_wifi_stats | awk '{print $1}')
      _dev_signal=$(echo $_wifi_stats | awk '{print $3}')
      _dev_snr=$(echo $_wifi_stats | awk '{print $4}')
      _dev_freq=$(echo $_wifi_stats | awk '{print $5}')
      _dev_mode=$(echo $_wifi_stats | awk '{print $6}')
    fi

    json_add_object "$_mac"
    json_add_string "ip" "$_ip"
    json_add_string "hostname" "$_hostname"
    json_add_string "conn_type" "$_conn_type"
    json_add_string "conn_speed" "$_conn_speed"
    json_add_string "wifi_signal" "$_dev_signal"
    json_add_string "wifi_snr" "$_dev_snr"
    json_add_string "wifi_freq" "$_dev_freq"
    json_add_string "wifi_mode" "$_dev_mode"
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

get_active_device_leases() {
  local _devarraystr="{\"data\":["
  local _devlist=$(cat /tmp/dhcp.leases | awk '{ print $2 }')
  local _hostname
  local _dev
  for _dev in $_devlist
  do
    _hostname=$(cat /tmp/dhcp.leases | grep "$_dev" | awk '{ print $4 }')
    _devarraystr="$_devarraystr\
{\"{#MAC}\":\"$_dev\", \"{#DEVHOSTNAME}\":\"$_hostname\"},"
  done
  _devarraystr=$_devarraystr"]}"
  echo $_devarraystr | sed 's/\(.*\),/\1/'
}
