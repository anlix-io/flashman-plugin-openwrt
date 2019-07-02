#!/bin/sh

. /usr/share/libubox/jshn.sh
. /usr/share/functions/device_functions.sh

get_device_mac_from_ip() {
  local _ip=$1
  local _arp_mac=$(cat /proc/net/arp | grep "$_ip" | awk '{ print $4 }')
  echo "$_arp_mac"
}

get_device_conn_type() {
  local _mac=$1
  local _online=$2
  local _retstatus

  is_device_wireless "$_mac"
  _retstatus=$?
  if [ $_retstatus -eq 0 ]
  then
    # Wireless
    echo "1"
  else
    if [ $_online -eq 1 ]
    then
      # Wired
      echo "0"
      return
    fi
    local _state=$(ip neigh | grep "$_mac" | awk '{print $NF}')
    for i in $_state
    do
      if [ "$i" = "STALE" ] || [ "$i" = "REACHABLE" ]
      then
        # Wired
        echo "0"
        return
      fi
    done
    # Not connected
    echo "2"
  fi
}

# IPV6 dhcp are uid not mac
# Send a probe to search for mac in ip neigh
get_ipv6_dhcp() {
  json_init
  local DHCP=$(ubus -v call dhcp ipv6leases)
  json_load "$DHCP"
  json_select "device"
  if json_get_type type "br-lan" && [ "$type" = object ]; then
    json_select "br-lan"
    if json_get_type type "leases" && [ "$type" = array ]; then
      json_select "leases"
      local Index="1"
      while json_get_type type $Index && [ "$type" = object ]; do
        json_select "$((Index++))"
        json_get_var duid "duid"
        json_select "ipv6-addr"
        local Index_Addr="1"
        while json_get_type type $Index_Addr && [ "$type" = object ]; do
          json_select "$((Index_Addr++))"
          json_get_var addrv6 "address"

          #we need to "wake up" the ip to get the mac from ip neigh
          ping6 -I br-lan -q -c 1 -w 1 "$addrv6" > /dev/null 2>&1
          local _macaddr=$(ip -6 neigh | grep "$addrv6" | awk '{ if($4 == "lladdr") print $5 }')
          if [ ! -z $_macaddr ]; then
            echo $duid $_macaddr $addrv6
          fi

          json_select ".."
        done
        json_select ".."
        json_select ".."
      done
    fi
  fi
}

get_online_devices() {
  local _dhcp_ipv6=$(get_ipv6_dhcp)
  local _arp_neigh=$(ip neigh | grep lladdr | awk '{ if($3 == "br-lan") print $5, $1 }')
  local _arp_macs=$(awk 'NR>1 { if($6 == "br-lan") print $4, $1 }' /proc/net/arp)
  local _arp_macs_all=$(printf %s\\n%s "$_arp_neigh" "$_arp_macs" | sort | uniq)
  local _arp_macs=$(echo "$_arp_macs_all" | awk '{ print $1 }' | uniq)

  json_init
  json_add_object "Devices"
  local _idx=1
  for _mac in $_arp_macs
  do
    local _ipv4="$(echo "$_arp_macs_all" | grep "$_mac" | awk '{ print $2 }' | grep \\.)"
    local _ipv6="$(echo "$_arp_macs_all" | grep "$_mac" | awk '{ print $2 }' | grep :)"

    # check online in ipv4
    local _online=0
    for i in $_ipv4
    do
      ping -q -c 1 -w 1 "$i" > /dev/null 2>&1
      if [ $? -eq 0 ]
      then
        _online=1
      fi
    done

    # check online in ipv6
    if [ $_online -eq 0 ]
    then
      for i in $_ipv6
      do
        ping6 -I br-lan -q -c 1 -w 1 "$i" > /dev/null 2>&1
        if [ $? -eq 0 ]
        then
          _online=1
        fi
      done
    fi

    # if cant connect, check arp table
    if [ $_online -eq 0 ]
    then
      local _count=0
      local _state=$(ip neigh | grep "$_mac" | awk '{print $NF}')
      local _ctrl=$(echo "$_state" | grep "DELAY")
      while [ ! -z "$_ctrl" ] || [ $_count -eq 2 ]
      do
        sleep 2
        _state=$(ip neigh | grep "$_mac" | awk '{print $NF}')
        _ctrl=$(echo "$_state" | grep "DELAY")
        _count=$((_count+1))
      done

      for s in $_state
      do
        if [ "$s" = "STALE" ] || [ "$s" = "REACHABLE" ]
        then
          _online=1
        fi
      done
    fi

    # if still offline, give up
    if [ $_online -eq 0 ]
    then
      # Not connected get next device
      _idx=$((_idx+1))
      continue
    fi

    local _hostname="$(cat /tmp/dhcp.leases | grep $_mac | \
                       awk '{ if ($4=="*") print "!"; else print $4 }')"
    local _conn_type="$(get_device_conn_type $_mac $_online)"
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
    json_add_string "ip" "$_ipv4"
    json_add_array "ipv6"
    for _i6 in $_ipv6
    do
      json_add_string "" "$_i6"
    done
    json_close_array
    json_add_array "dhcpv6"
    for _i6 in $(echo  "$_dhcp_ipv6" | grep $_mac | awk '{print $3}')
    do
      json_add_string "" "$_i6"
    done
    json_close_array
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
