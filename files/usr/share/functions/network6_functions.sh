
get_wan6_iface() {
  local _w6="wan6"
  network_find_wan6 _w6
  echo $_w6
}

get_ipv6_enabled() {
  local _ipv6_enabled=1
  if [ "$(get_bridge_mode_status)" != "y" ]
  then
    [ "$(uci -q get network.wan.ipv6)" = "0" ] && _ipv6_enabled=0
  else
    [ "$(uci -q get network.lan.ipv6)" = "0" ] && _ipv6_enabled=0
  fi
  echo "$_ipv6_enabled"
}

enable_ipv6() {
  if [ "$(get_bridge_mode_status)" != "y" ]
  then
    # Router Mode
    uci set network.wan.ipv6="auto"
    uci set network.wan6.proto="dhcpv6"

    [ "$(uci -q get network.lan.ipv6)" ] && uci delete network.lan.ipv6
    [ "$(uci -q get network.lan6)" ] && uci delete network.lan6
  else
    # Bridge Mode
    uci set network.wan.ipv6="auto"
    uci set network.wan6.proto="none"
    uci set network.lan.ipv6="auto"
    if [ -z "$(uci -q get network.lan6)" ]
    then
      uci set network.lan6=interface
      uci set network.lan6.ifname='@lan'
    fi
    uci set network.lan6.proto='dhcpv6'
  fi
  uci commit network

  # Set ssh configuration for ipv6
  # Warning: Make sure the dropbear[1] does not exist in 
  # /rom/etc/config/dropbear, this is the default config
  if [ "$(uci -q get dropbear.@dropbear[1])" == 'dropbear' ]
  then
    uci set dropbear.@dropbear[1].enable=1
    uci commit dropbear
  fi

  json_cleanup
  json_load_file /root/flashbox_config.json
  json_add_string enable_ipv6 "1"
  json_dump > /root/flashbox_config.json
  json_close_object
}

disable_ipv6() {
  uci set network.wan.ipv6="0"
  uci set network.wan6.proto='none'
  uci set network.lan.ipv6="0"
  [ "$(uci -q get network.lan6)" ] && uci delete network.lan6
  uci commit network

  # Set ssh configuration for ipv6
  # Warning: Make sure the dropbear[1] does not exist in 
  # /rom/etc/config/dropbear, this is the default config
  if [ "$(uci -q get dropbear.@dropbear[1])" == 'dropbear' ]
  then
    uci set dropbear.@dropbear[1].enable=0
    uci commit dropbear
  fi

  json_cleanup
  json_load_file /root/flashbox_config.json
  json_add_string enable_ipv6 "0"
  json_dump > /root/flashbox_config.json
  json_close_object
}

check_connectivity_ipv6() {
  local _ip="2001:4860:4860::8888"
  local _ipv6_connectivity=1

  if [ "$(get_ipv6_enabled)" != "0" ]
  then
    if ping6 -q -c 1 -w 2 "$_ip" > /dev/null 2>&1
    then
      _ipv6_connectivity=0
    fi
  fi
  echo $_ipv6_connectivity
}

check_connectivity_flashman() {
  _addrs="$FLM_SVADDR"
  check_connectivity_internet "$_addrs"
}

get_wan_ipv6() {
  local _ip=""
  if [ "$(get_bridge_mode_status)" != "y" ]
  then
    network_get_ipaddr6 _ip $(get_wan6_iface)
  else
    # Do not write "none" in case of bridge
    _ip="$(get_lan_bridge_ipv6addr)"
  fi
  echo "$_ip"
}

get_wan_ipv6_mask() {
  local _mask=""

  # /lib/functions/network.sh does not provide this info
  # but the private function that gets the field is avaiable
  __network_ifstatus "_mask" "$(get_wan6_iface)" "['ipv6-address'][0].mask"

  echo "$_mask"
}

get_gateway6() {
  local _gateway=""

  network_get_gateway6 _gateway $(get_wan6_iface)

  echo "$_gateway"
}

# Prefix Delegation Address
get_prefix_delegation_addres() {
  local _prefix=""

  # /lib/functions/network.sh does not provide this info
  # but the private function that gets the field is avaiable
  __network_ifstatus "_prefix" "lan" "['ipv6-prefix-assignment'][0].address"

  echo "$_prefix"
}


# Prefix Delegation Mask
get_prefix_delegation_mask() {
  local _mask=""

  # /lib/functions/network.sh does not provide this info
  # but the private function that gets the field is avaiable
  __network_ifstatus "_mask" "lan" "['ipv6-prefix-assignment'][0]['local-address'].mask"

  echo "$_mask"
}


# Prefix Delegation Local Address
get_prefix_delegation_local_address() {
  local _address=""

  # /lib/functions/network.sh does not provide this info
  # but the private function that gets the field is avaiable
  __network_ifstatus "_address" "lan" "['ipv6-prefix-assignment'][0]['local-address'].address"

  echo "$_address"
}

add_static_ipv6() {
  local _mac=$1

  # do not create new entry
  local i=0
  local _idtmp=$(uci -q get dhcp.@host[$i].mac)
  while [ $? -eq 0 ]; do
    if [ "$_idtmp" = "$_mac" ]
    then
      local _addr=$(uci -q get dhcp.@host[$i].hostid)
      if [ ! -z "$_addr" ]
      then
        echo "$_addr"
        return
      fi
    fi
    i=$((i+1))
    _idtmp=$(uci -q get dhcp.@host[$i].mac)
  done

  # no entry found, create new
  local _dhcp_ipv6=$(get_ipv6_dhcp | grep "$_mac")
  if [ -n "$_dhcp_ipv6" ]
  then
    local _duid=$(echo "$_dhcp_ipv6" | awk '{print $1}')
    local _addr=$(echo "$_dhcp_ipv6" | awk '{print $3}')

    uci -q add dhcp host > /dev/null
    uci -q set dhcp.@host[-1].mac="$_mac"
    uci -q set dhcp.@host[-1].duid="$_duid"
    uci -q set dhcp.@host[-1].hostid="${_addr#*::}"
    uci -q commit dhcp

    #return just the first
    echo "${_addr#*::}"
  fi
}
