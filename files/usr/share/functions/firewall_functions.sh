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

      json_select port
      local _port_idx=1
      while json_get_type _port_type $_port_idx && [ "$_port_type" = int ]
      do
        json_get_var _port "$((_port_idx++))"
        uci add firewall redirect
        uci set firewall.@redirect[-1].src='wan'
        uci set firewall.@redirect[-1].src_dport="$_port"
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
