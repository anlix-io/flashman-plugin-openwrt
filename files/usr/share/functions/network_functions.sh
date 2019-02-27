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
  fi
}

valid_ip() {
  local ip=$1
  local filtered_ip
  local stat=1
  local b1
  local b2
  local b3
  local b4

  filtered_ip=$(printf "%s\n" "$ip" |
                grep -E '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$')

  if [ "$filtered_ip" != "" ]
  then
    b1="$(echo $ip | awk -F. '{print $1}')"
    b2="$(echo $ip | awk -F. '{print $2}')"
    b3="$(echo $ip | awk -F. '{print $3}')"
    b4="$(echo $ip | awk -F. '{print $4}')"

    [[ $b1 -le 255 && $b2 -le 255 && $b3 -le 255 && $b4 -le 255 ]]
    stat=$?
  fi
  return $stat
}

get_lan_subnet() {
  local _ipcalc_res
  local _uci_lan_ipaddr
  local _uci_lan_netmask
  local _lan_addr
  _uci_lan_ipaddr=$(uci get network.lan.ipaddr)
  _uci_lan_netmask=$(uci get network.lan.netmask)
  _ipcalc_res="$(/bin/ipcalc.sh $_uci_lan_ipaddr $_uci_lan_netmask)"
  _lan_addr="$(echo "$_ipcalc_res" | grep "NETWORK" | awk -F= '{print $2}')"

  echo "$_lan_addr"
}

get_lan_netmask() {
  local _ipcalc_res
  local _uci_lan_ipaddr
  local _uci_lan_netmask
  local _lan_netmask
  _uci_lan_ipaddr=$(uci get network.lan.ipaddr)
  _uci_lan_netmask=$(uci get network.lan.netmask)
  _ipcalc_res="$(/bin/ipcalc.sh $_uci_lan_ipaddr $_uci_lan_netmask)"
  _lan_netmask="$(echo "$_ipcalc_res" | grep "PREFIX" | awk -F= '{print $2}')"

  echo "$_lan_netmask"
}

set_lan_subnet() {
  local _lan_addr
  local _lan_netmask
  local _lan_net
  local _retstatus
  local _ipcalc_res
  local _ipcalc_netmask
  local _ipcalc_addr
  local _current_lan_net=$(get_lan_subnet)
  _lan_addr=$1
  _lan_netmask=$2

  # Validate LAN gateway address
  valid_ip "$_lan_addr"
  _retstatus=$?
  if [ $_retstatus -eq 0 ]
  then
    _ipcalc_res="$(/bin/ipcalc.sh $_lan_addr $_lan_netmask 1 255)"

    _ipcalc_netmask=$(echo "$_ipcalc_res" | grep "PREFIX" | \
                      awk -F= '{print $2}')
    # Accepted netmasks: 24 to 26
    if [ $_ipcalc_netmask -ge 24 ] && [ $_ipcalc_netmask -le 26 ]
    then
      # Valid netmask
      _lan_netmask="$_ipcalc_netmask"
      # Use first address available returned by ipcalc
      _ipcalc_addr=$(echo "$_ipcalc_res" | grep "START" | awk -F= '{print $2}')
      _lan_addr="$_ipcalc_addr"
      _lan_net=$(echo "$_ipcalc_res" | grep "NETWORK" | awk -F= '{print $2}')
      # Calculate DHCP start and limit
      _addr_net=$(echo "$_ipcalc_res" | grep "NETWORK" | awk -F. '{print $4}')
      _addr_end=$(echo "$_ipcalc_res" | grep "END" | awk -F. '{print $4}')
      _addr_limit=$(( (_addr_end - _addr_net) / 2 ))
      _addr_start=$(( _addr_end - _addr_limit ))

      # DMZ lan is forbidden
      local _dmzprefix="$(echo $_lan_net | awk -F. '{print $1$2$3}')"
      if [ "$_dmzprefix" = "19216843" ]
      then
        # Error. DMZ is forbidden
        return 1
      fi

      # Only change LAN if its not the same
      if [ "$_lan_net" != "$_current_lan_net" ]
      then
        uci set network.lan.ipaddr="$_lan_addr"
        uci set network.lan.netmask="$_lan_netmask"
        uci commit network
        uci set dhcp.lan.start="$_addr_start"
        uci set dhcp.lan.limit="$_addr_limit"
        uci commit dhcp

        /etc/init.d/network restart
        /etc/init.d/odhcpd restart # Must restart to fix IPv6 leasing
        /etc/init.d/dnsmasq reload

        # Replace IP so Flash App can find the router
        sed -i 's/.*anlixrouter/'"$_lan_addr"' anlixrouter/' /etc/hosts

        # Save LAN config
        json_cleanup
        json_load_file /root/flashbox_config.json
        json_add_string lan_addr "$_lan_net"
        json_add_string lan_netmask "$_lan_netmask"
        json_dump > /root/flashbox_config.json
        json_close_object

        return 0
      else
        # No change
        return 1
      fi
    else
      # Parse error
      return 1
    fi
  else
    # Parse error
    return 1
  fi
}

# Arg 1: IP address to check, Arg 2: LAN subnet, Arg 3: LAN netmask
is_ip_in_lan() {
  local _device_ip
  local _lan_subnet
  local _lan_netmask
  local _ipcalc_res
  local _ipcalc_addr

  if [ $# -eq 3 ] && [ "$1" ]
  then
    _device_ip=$1
    _lan_subnet=$2
    _lan_netmask=$3
    _ipcalc_res="$(/bin/ipcalc.sh $_lan_subnet $_lan_netmask $_device_ip)"
    _ipcalc_addr=$(echo "$_ipcalc_res" | grep "START" | awk -F= '{print $2}')
    if [ "$_ipcalc_addr" = "$_device_ip" ]
    then
      # IP belongs to LAN subnet
      return 0
    else
      # No match
      return 1
    fi
  else
    # Error
    return 1
  fi
}

add_static_ip() {
  local _mac=$1
  local _dmz=$2
  local _device_ip=$(grep "$_mac" /tmp/dhcp.leases | awk '{print $3}')
  local _lan_subnet=$(get_lan_subnet)
  local _lan_netmask=$(get_lan_netmask)
  local _dmz_subnet="192.168.43.0"
  local _dmz_netmask="24"
  local _device_on_lan
  local _device_on_dmz
  local _fixed_ip
  local _ipcalc_res
  local _next_addr=""

  is_ip_in_lan "$_device_ip" "$_lan_subnet" "$_lan_netmask"
  _device_on_lan=$?
  is_ip_in_lan "$_device_ip" "$_dmz_subnet" "$_dmz_netmask"
  _device_on_dmz=$?

  # Device is online. Use the same ip address
  if [ "$_device_ip" ]
  then
    if { [ "$_dmz" = "1" ] && [ $_device_on_dmz -eq 0 ]; } || \
       { [ "$_dmz" = "0" ] && [ $_device_on_lan -eq 0 ]; }
    then
      echo "$_mac $_device_ip" >> /etc/ethers
      echo "$_device_ip"
      return
    fi
  fi

  # Device is offline. Choose an ip address 
  if [ "$_dmz" = "1" ]
  then
    if [ -f /etc/ethers ]
    then
      while read _fixed_ip
      do
        is_ip_in_lan "$_fixed_ip" "$_dmz_subnet" "$_dmz_netmask"
        if [ $? -eq 0 ]
        then
          _ipcalc_res="$(/bin/ipcalc.sh $_dmz_subnet \
                         $_dmz_netmask $_fixed_ip 1)"
          _next_addr="$(echo "$_ipcalc_res" | grep "END" | \
                        awk -F= '{print $2}')"
        fi
      done < /etc/ethers
    else
      # It must start at 130 to isolate routes
      _ipcalc_res="$(/bin/ipcalc.sh $_dmz_subnet $_dmz_netmask 1 129)"
      _next_addr="$(echo "$_ipcalc_res" | grep "END" | awk -F= '{print $2}')"
    fi
  else
    if [ -f /etc/ethers ]
    then
      while read _fixed_ip
      do
        is_ip_in_lan "$_fixed_ip" "$_lan_subnet" "$_lan_netmask"
        if [ $? -eq 0 ]
        then
          _ipcalc_res="$(/bin/ipcalc.sh $_lan_subnet \
                         $_lan_netmask $_fixed_ip 1)"
          _next_addr="$(echo "$_ipcalc_res" | grep "END" | \
                        awk -F= '{print $2}')"
        fi
      done < /etc/ethers
    else
      _ipcalc_res="$(/bin/ipcalc.sh $_lan_subnet $_lan_netmask 1 1)"
      _next_addr="$(echo "$_ipcalc_res" | grep "END" | awk -F= '{print $2}')"
    fi
  fi
  echo "$_mac $_next_addr" >> /etc/ethers
  echo "$_next_addr"
}
