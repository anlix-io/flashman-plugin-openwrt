#!/bin/sh

. /usr/share/flashman_init.conf
. /usr/share/functions/common_functions.sh
. /usr/share/libubox/jshn.sh
. /lib/functions/network.sh

get_wan_ip() {
  local _ip=""
  network_get_ipaddr _ip wan
  echo "$_ip"
}

get_wan_type() {
  echo "$(uci get network.wan.proto | awk '{ print tolower($1) }')"
}

set_wan_type() {
  local _wan_type=$(get_wan_type)
  local _wan_type_remote=$1
  local _pppoe_user_remote=$2
  local _pppoe_password_remote=$3

  if [ "$_wan_type_remote" != "$_wan_type" ]
  then
    if [ "$_wan_type_remote" = "dhcp" ]
    then
      log "FLASHMAN UPDATER" "Updating connection type to DHCP ..."
      uci set network.wan.proto="dhcp"
      uci set network.wan.username=""
      uci set network.wan.password=""
      uci set network.wan.service=""
      uci commit network

      /etc/init.d/network restart
      /etc/init.d/odhcpd restart # Must restart to fix IPv6 leasing

      # This will persist connection type between firmware upgrades
      json_cleanup
      json_load_file /root/flashbox_config.json
      json_add_string wan_conn_type "dhcp"
      json_add_string pppoe_user ""
      json_add_string pppoe_pass ""
      json_dump > /root/flashbox_config.json
      json_close_object
    elif [ "$_wan_type_remote" = "pppoe" ]
    then
      if [ "$_pppoe_user_remote" != "" ] && [ "$_pppoe_password_remote" != "" ]
      then
        log "FLASHMAN UPDATER" "Updating connection type to PPPOE ..."
        uci set network.wan.proto="pppoe"
        uci set network.wan.username="$_pppoe_user_remote"
        uci set network.wan.password="$_pppoe_password_remote"
        uci set network.wan.service="$FLM_WAN_PPPOE_SERVICE"
        uci set network.wan.keepalive="60 3"
        uci commit network

        /etc/init.d/network restart
        /etc/init.d/odhcpd restart # Must restart to fix IPv6 leasing

        # This will persist connection type between firmware upgrades
        json_cleanup
        json_load_file /root/flashbox_config.json
        json_add_string wan_conn_type "pppoe"
        json_add_string pppoe_user "$_pppoe_user_remote"
        json_add_string pppoe_pass "$_pppoe_password_remote"
        json_dump > /root/flashbox_config.json
        json_close_object
      fi
    fi
    # Don't put anything outside here. _content_type may be corrupted
  fi
}

set_pppoe_credentials() {
  local _wan_type=$(get_wan_type)
  local _pppoe_user_remote=$1
  local _pppoe_password_remote=$2
  local _pppoe_user_local=$(uci -q get network.wan.username)
  local _pppoe_password_local=$(uci -q get network.wan.password)

  if [ "$_wan_type" = "pppoe" ]
  then
    if [ "$_pppoe_user_remote" != "" ] && [ "$_pppoe_password_remote" != "" ]
    then
      if [ "$_pppoe_user_remote" != "$_pppoe_user_local" ] || \
         [ "$_pppoe_password_remote" != "$_pppoe_password_local" ]
      then
        log "FLASHMAN UPDATER" "Updating PPPoE ..."
        uci set network.wan.username="$_pppoe_user_remote"
        uci set network.wan.password="$_pppoe_password_remote"
        uci commit network

        /etc/init.d/network restart
        /etc/init.d/odhcpd restart # Must restart to fix IPv6 leasing
      fi
    fi
  fi
}

add_static_ip() {
  local _mac=$1
  local _dmz=$2
  local _device_ip=$(grep "$_mac" /tmp/dhcp.leases | awk '{print $3}')

  # Device is online: use the same ip address
  if [ "$_device_ip" ] && [ "$_dmz" = "1" ] && \
     [ "${_device_ip:0:10}" = "192.168.43" ]
  then
    echo "$_mac $_device_ip" >> /etc/ethers
    echo "$_device_ip"
    return
  fi

  if [ "$_device_ip" ] && [ "$_dmz" = "0" ] && \
     [ "${_device_ip:0:7}" = "10.0.10" ]
  then
    echo "$_mac $_device_ip" >> /etc/ethers
    echo "$_device_ip"
    return
  fi

  # Device is offline, choose an ip address 
  local _next_dmz_ip_id=""
  if [ "$_dmz" = "1" ]
  then
    if [ -f /etc/ethers ]
    then
      _next_dmz_ip_id=$(grep 192.168.43 /etc/ethers | \
                        awk '{print substr($2,length($2)-2,3)}' | tail -1)
    fi
    if [ ! "$_next_dmz_ip_id" ]
    then
      _next_dmz_ip_id="130"
    else
      _next_dmz_ip_id=$((_next_dmz_ip_id+1))
    fi
    echo "$_mac 192.168.43.$_next_dmz_ip_id" >> /etc/ethers
    echo "192.168.43.$_next_dmz_ip_id"
  else
    if [ -f /etc/ethers ]
    then
      _next_dmz_ip_id=$(grep 10.0.10 /etc/ethers | \
                        awk '{print substr($2,length($2)-1,2)}' | tail -1)
    fi
    if [ ! "$_next_dmz_ip_id" ]
    then
      _next_dmz_ip_id="50"
    else
      _next_dmz_ip_id=$((_next_dmz_ip_id+1))
    fi
    echo "$_mac 10.0.10.$_next_dmz_ip_id" >> /etc/ethers
    echo "10.0.10.$_next_dmz_ip_id"
  fi
}
