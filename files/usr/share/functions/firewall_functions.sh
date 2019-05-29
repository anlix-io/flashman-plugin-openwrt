#!/bin/sh

. /usr/share/flashman_init.conf
. /usr/share/functions/common_functions.sh
. /usr/share/functions/network_functions.sh
. /usr/share/libubox/jshn.sh

json_update_index() {
  _index=$1
  _json_var=$2

  json_init
  [ -f /etc/anlix_indexes ] && json_load_file /etc/anlix_indexes
  json_add_string "$_json_var" "$_index"
  json_close_object
  json_dump > /etc/anlix_indexes
}

get_forward_indexes() {
  local _index=$1
  local _idx_val=""

  if [ -f /etc/anlix_indexes ]
  then
    json_cleanup
    json_load_file /etc/anlix_indexes
    json_get_var _idx_val "$_index"
    json_close_object
  fi
  echo "$_idx_val"
}

update_port_forward() {
  log "PORT FORWARD" "Requesting Flashman ..."
  local _data="id=$(get_mac)"
  local _url="deviceinfo/get/portforward/"
  local _res
  local _retstatus
  _res=$(rest_flashman "$_url" "$_data")
  _retstatus=$?

  if [ $_retstatus -eq 0 ]
  then
    json_cleanup
    json_load "$_res"
    json_get_var _flash_idx forward_index

    [ -f /etc/ethers ] && rm /etc/ethers

    # Remove old forward rules
    local _old_rules=$(uci -X show firewall | grep ".name='anlix_forward_.*'")
    for rule in $_old_rules
    do
      local _old_rule=$(echo "$rule" | awk -F '.' '{ print "firewall."$2}')
      uci delete "$_old_rule"
    done

    json_select forward_rules
    local _rule_idx="1"
    local _forward_idx=1
    while json_get_type _rule_type $_rule_idx && [ "$_rule_type" = object ]
    do
      json_select "$((_rule_idx++))"
      json_get_var _mac mac
      json_get_var _dmz dmz
      local _static_ip=$(add_static_ip "$_mac" "$_dmz")
      local _static_ipv6=$(add_static_ipv6 "$_mac")

      local has_router_port=0
      json_get_type _router_port_type router_port
      if [ "$_router_port_type" == "array" ]
      then
        json_select router_port
        local _router_port_idx=1
        while json_get_type _router_port_type $_router_port_idx && [ "$_router_port_type" = int ]
        do
          has_router_port=1
          json_get_var _router_port "$_router_port_idx"
          eval _router_port_$_router_port_idx=$_router_port
          _router_port_idx=$((_router_port_idx+1))
        done
        json_select ".."
      fi

      json_select port
      local _port_idx=1
      while json_get_type _port_type $_port_idx && [ "$_port_type" = int ]
      do
        local _act_idx="$((_port_idx++))"
        json_get_var _port $_act_idx

        #IPV4
        uci add firewall redirect > /dev/null
        uci set firewall.@redirect[-1].src='wan'

        if [ $has_router_port -eq 1 ]
        then
          eval _src_port=\$_router_port_$_act_idx
          if [ $_src_port -eq $_port ]
          then
             uci set firewall.@redirect[-1].src_dport="$_port"
          else
             uci set firewall.@redirect[-1].src_dport="$_src_port"
             uci set firewall.@redirect[-1].dest_port="$_port"
          fi
        else
          uci set firewall.@redirect[-1].src_dport="$_port"
        fi

        uci set firewall.@redirect[-1].proto='tcpudp'
        if [ "$_dmz" = 1 ]
        then
          uci set firewall.@redirect[-1].dest='dmz'
        else
          uci set firewall.@redirect[-1].dest='lan'
        fi
        uci set firewall.@redirect[-1].dest_ip="$_static_ip"
        uci set firewall.@redirect[-1].target="DNAT"
        uci set firewall.@redirect[-1].name="anlix_forward_$((_forward_idx++))"

        #IPV6
        if [ ! -z "$_static_ipv6" ]
        then
          uci add firewall rule > /dev/null
          uci set firewall.@rule[-1].src='wan'
          uci set firewall.@rule[-1].proto='tcpudp'
          uci set firewall.@rule[-1].dest='lan'
          uci set firewall.@rule[-1].dest_ip="::$_static_ipv6/::ffff"
          uci set firewall.@rule[-1].dest_port="$_port"
          uci set firewall.@rule[-1].family='ipv6'
          uci set firewall.@rule[-1].target='ACCEPT'
          uci set firewall.@rule[-1].name="anlix_forward_$((_forward_idx++))"
        fi

      done
      json_select ".."
      json_select ".."
    done
    json_close_object
    uci commit firewall
    /etc/init.d/dnsmasq reload
    /etc/init.d/firewall reload

    # Save index
    json_update_index "$_flash_idx" "forward_index"
  fi
}

update_blocked_devices() {
  local _blocked_devices="$1"
  local _blocked_macs="$2"
  local _blocked_devices_index="$3"

  # Blocked devices firewall update - always do this to avoid file diff logic
  log "FLASHMAN UPDATER" "Rewriting user firewall rules ..."
  rm /etc/firewall.user
  touch /etc/firewall.user
  echo -n "$_blocked_devices" > /tmp/blacklist_mac
  for mac in $_blocked_macs
  do
    echo "iptables -I FORWARD -m mac --mac-source $mac -j DROP" >> \
         /etc/firewall.user
    echo "ip6tables -I FORWARD -m mac --mac-source $mac -j DROP" >> \
         /etc/firewall.user
  done
  /etc/init.d/firewall restart
  /etc/init.d/odhcpd restart # Must restart to fix IPv6 leasing

  # Save index
  json_update_index "$_blocked_devices_index" "blocked_devices_index"
}
