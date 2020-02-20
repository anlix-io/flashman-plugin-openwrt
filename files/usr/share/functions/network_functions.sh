#!/bin/sh

. /usr/share/flashman_init.conf
. /usr/share/functions/common_functions.sh
. /usr/share/functions/dhcp_functions.sh
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

get_lan_ipaddr() {
  local _uci_lan_ipaddr
  _uci_lan_ipaddr=$(uci get network.lan.ipaddr)
  echo "$_uci_lan_ipaddr"
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
  local _current_lan_ipaddr=$(get_lan_ipaddr)
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
      _ipcalc_addr=$(echo "$_ipcalc_res" | grep "IP" | awk -F= '{print $2}')
      _lan_net=$(echo "$_ipcalc_res" | grep "NETWORK" | awk -F= '{print $2}')
      # Avoid placing subnet IP by mistake
      if [ "$_lan_net" = "$_ipcalc_addr" ]
      then
        _ipcalc_addr=$(echo "$_ipcalc_res" | grep "START" | awk -F= '{print $2}')
      fi
      # Assign LAN router ip
      _lan_addr="$_ipcalc_addr"
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
      if [ "$_lan_addr" != "$_current_lan_ipaddr" ]
      then
        uci set network.lan.ipaddr="$_lan_addr"
        uci set network.lan.netmask="$_lan_netmask"
        uci commit network
        uci set dhcp.lan.start="$_addr_start"
        uci set dhcp.lan.limit="$_addr_limit"
        uci commit dhcp

        # Replace IP so Flash App can find the router
        sed -i 's/.*anlixrouter/'"$_lan_addr"' anlixrouter/' /etc/hosts

        /etc/init.d/network restart
        /etc/init.d/odhcpd restart # Must restart to fix IPv6 leasing
        /etc/init.d/dnsmasq reload
        /etc/init.d/uhttpd restart # Must restart to update Flash App API

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
  if [ ! -z "$_dhcp_ipv6" ]
  then
    for _i6 in "$_dhcp_ipv6"
    do
      local _duid=$(echo $_i6 | awk '{print $1}')
      local _addr=$(echo $_i6 | awk '{print $3}')

      uci -q add dhcp host > /dev/null
      uci -q set dhcp.@host[-1].mac="$_mac"
      uci -q set dhcp.@host[-1].duid="$_duid"
      uci -q set dhcp.@host[-1].hostid="${_addr#*::}"
      uci -q commit dhcp

      #return just the first
      echo "${_addr#*::}"
      return
    done
  fi
}

add_static_ip() {
  local _mac=$1
  local _dmz=$2
  local _ethers_file="$3"
  local _ipv4_neigh="$(ip -4 neigh | grep lladdr | awk '{ if($3 == "br-lan") print $5, $1}')"
  local _device_ip="$(echo "$_ipv4_neigh" | grep "$_mac" | awk '{ print $2 }')"
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
      echo "$_mac $_device_ip" >> /etc/$_ethers_file
      echo "$_device_ip"
      return
    fi
  fi

  # Device is offline. Choose an ip address 
  if [ "$_dmz" = "1" ]
  then
    if [ -f /etc/$_ethers_file ]
    then
      while read _fixed_ip
      do
        _fixed_ip="$(echo "$_fixed_ip" | awk '{print $2}')"
        is_ip_in_lan "$_fixed_ip" "$_dmz_subnet" "$_dmz_netmask"
        if [ $? -eq 0 ]
        then
          _ipcalc_res="$(/bin/ipcalc.sh $_dmz_subnet \
                         $_dmz_netmask $_fixed_ip 1)"
          _next_addr="$(echo "$_ipcalc_res" | grep "END" | \
                        awk -F= '{print $2}')"
        fi
      done < /etc/$_ethers_file
      if [ "$_next_addr" = "" ]
      then
        # It must start at 130 to isolate routes
        _ipcalc_res="$(/bin/ipcalc.sh $_dmz_subnet $_dmz_netmask 1 129)"
        _next_addr="$(echo "$_ipcalc_res" | grep "END" | awk -F= '{print $2}')"
      fi
    else
      # It must start at 130 to isolate routes
      _ipcalc_res="$(/bin/ipcalc.sh $_dmz_subnet $_dmz_netmask 1 129)"
      _next_addr="$(echo "$_ipcalc_res" | grep "END" | awk -F= '{print $2}')"
    fi
  else
    if [ -f /etc/$_ethers_file ]
    then
      while read _fixed_ip
      do
        _fixed_ip="$(echo "$_fixed_ip" | awk '{print $2}')"
        is_ip_in_lan "$_fixed_ip" "$_lan_subnet" "$_lan_netmask"
        if [ $? -eq 0 ]
        then
          _ipcalc_res="$(/bin/ipcalc.sh $_lan_subnet \
                         $_lan_netmask $_fixed_ip 1)"
          _next_addr="$(echo "$_ipcalc_res" | grep "END" | \
                        awk -F= '{print $2}')"
        fi
      done < /etc/$_ethers_file
      if [ "$_next_addr" = "" ]
      then
        _ipcalc_res="$(/bin/ipcalc.sh $_lan_subnet $_lan_netmask 1 1)"
        _next_addr="$(echo "$_ipcalc_res" | grep "END" | awk -F= '{print $2}')"
      fi
    else
      _ipcalc_res="$(/bin/ipcalc.sh $_lan_subnet $_lan_netmask 1 1)"
      _next_addr="$(echo "$_ipcalc_res" | grep "END" | awk -F= '{print $2}')"
    fi
  fi
  echo "$_mac $_next_addr" >> /etc/$_ethers_file
  echo "$_next_addr"
}

get_use_dns_proxy() {
  local _current_dnsproxy

  _current_dnsproxy="$(uci get dhcp.@dnsmasq[0].noproxy)"
  if [ $? -eq 0 ]
  then
    echo "$_current_dnsproxy"
  else
    # If not set than use default
    echo "$FLM_DHCP_NOPROXY"
  fi
}

set_use_dns_proxy() {
  local _no_dnsproxy
  local _current_dnsproxy

  _no_dnsproxy=$1
  if [ "$_no_dnsproxy" != "1" ] && [ "$_no_dnsproxy" != "0" ]
  then
    # Invalid value
    return
  fi

  _current_dnsproxy="$(uci get dhcp.@dnsmasq[0].noproxy)"
  if [ $? -eq 0 ]
  then
    if [ "$_current_dnsproxy" != "$_no_dnsproxy" ]
    then
      if [ "$_no_dnsproxy" == "1" ]
      then
        uci set dhcp.@dnsmasq[0].noproxy='1'
      else
        uci set dhcp.@dnsmasq[0].noproxy='0'
      fi
      uci commit dhcp
      /etc/init.d/dnsmasq reload
      /etc/init.d/odhcpd reload
    fi
  fi

  return
}

get_bridge_mode_status() {
  local _status=""
  json_cleanup
  json_load_file /root/flashbox_config.json
  json_get_var _status bridge_mode
  json_close_object
  echo "$_status"
}

enable_bridge_mode() {
  local _disable_switch=$1
  local _fixed_ip=$2
  local _fixed_gateway=$3
  local _fixed_dns=$4
  # Get ifnames to bridge them together
  local _lan_ip="$(uci get network.lan.ipaddr)"
  local _lan_ifnames="$(uci get network.lan.ifname)"
  local _wan_ifnames="$(uci get network.wan.ifname)"
  # Separate non-wifi interfaces to back them up
  _lan_ifnames_wifi=""
  for iface in $_lan_ifnames
  do
    if [ "$(echo $iface | grep ra)" != "" ]
    then
      _lan_ifnames_wifi="$iface $_lan_ifnames_wifi"
    fi
  done
  # Write bridge mode to config.json so it persists between flashes
  json_cleanup
  json_load_file /root/flashbox_config.json
  json_add_string bridge_mode "y"
  json_add_string bridge_lan_backup "$_lan_ifnames"
  json_add_string bridge_lan_ip_backup "$_lan_ip"
  json_add_string bridge_disable_switch "$_disable_switch"
  json_add_string bridge_fix_ip "$_fixed_ip"
  json_add_string bridge_fix_gateway "$_fixed_gateway"
  json_add_string bridge_fix_dns "$_fixed_dns"
  json_dump > /root/flashbox_config.json
  json_close_object
  # Disable wan and bridge interfaces in lan
  uci set network.wan.proto="none"
  uci set network.wan6.proto="none"
  if [ "$_fixed_ip" != "" ]
  then
    uci set network.lan.ipaddr="$_fixed_ip"
    uci set network.lan.gateway="$_fixed_gateway"
    uci set network.lan.dns="$_fixed_dns"
  else
    uci set network.lan.proto="dhcp"
  fi
  if [ "$_disable_switch" = "y" ]
  then
    uci set network.lan.ifname="$_wan_ifnames $_lan_ifnames_wifi"
  else
    uci set network.lan.ifname="$_wan_ifnames $_lan_ifnames"
  fi
  # Disable dns, dhcp and dhcp6
  /etc/init.d/miniupnpd disable
  /etc/init.d/miniupnpd stop
  /etc/init.d/firewall disable
  /etc/init.d/firewall stop
  /etc/init.d/dnsmasq disable
  /etc/init.d/dnsmasq stop
  /etc/init.d/odhcpd disable
  /etc/init.d/odhcpd stop
  # Save changes and reboot network
  uci commit network
  /etc/init.d/network restart
}

update_bridge_mode() {
  local _disable_switch=$1
  local _fixed_ip=$2
  local _fixed_gateway=$3
  local _fixed_dns=$4
  local _current_switch=""
  local _current_ip=""
  local _current_gateway=""
  local _current_dns=""
  local _lan_ifnames=""
  local _wan_ifnames=""
  local _lan_ifnames_wifi=""
  json_cleanup
  json_load_file /root/flashbox_config.json
  json_get_var _current_switch bridge_disable_switch
  json_get_var _current_ip bridge_fix_ip
  json_get_var _current_gateway bridge_fix_gateway
  json_get_var _current_dns bridge_fix_dns
  # Update ip, gateway, dns if needed
  if [ "$_current_ip" != "$_fixed_ip" ]
  then
    uci set network.lan.ipaddr="$_fixed_ip"
    json_add_string bridge_fix_ip "$_fixed_ip"
  fi
  if [ "$_current_gateway" != "$_fixed_gateway" ]
  then
    uci set network.lan.gateway="$_fixed_gateway"
    json_add_string bridge_fix_gateway "$_fixed_gateway"
  fi
  if [ "$_current_dns" != "$_fixed_dns" ]
  then
    uci set network.lan.gateway="$_fixed_dns"
    json_add_string bridge_fix_dns "$_fixed_dns"
  fi
  # Update switch disable flag if needed
  if [ "$_current_switch" != "$_disable_switch" ]
  then
    json_add_string bridge_disable_switch "$_disable_switch"
    json_get_var _lan_ifnames bridge_lan_backup
    _wan_ifnames="$(uci get network.wan.ifname)"
    if [ "$_current_switch" = "y" ]
    then
      _lan_ifnames_wifi=""
      for iface in $_lan_ifnames
      do
        if [ "$(echo $iface | grep ra)" != "" ]
        then
          _lan_ifnames_wifi="$iface $_lan_ifnames_wifi"
        fi
      done
      uci set network.lan.ifname="$_wan_ifnames $_lan_ifnames_wifi"
    else
      uci set network.lan.ifname="$_wan_ifnames $_lan_ifnames"
    fi
  fi
  json_dump > /root/flashbox_config.json
  json_close_object
  uci commit network
  /etc/init.d/network restart
}

disable_bridge_mode() {
  local _wan_conn_type=""
  local _lan_ifnames=""
  local _lan_ip=""
  # Clear bridge mode from config.json so it doesn't persist between flashes
  json_cleanup
  json_load_file /root/flashbox_config.json
  json_get_var _wan_conn_type wan_conn_type
  json_get_var _lan_ifnames bridge_lan_backup
  json_get_var _lan_ip bridge_lan_ip_backup
  json_add_string bridge_mode "n"
  json_dump > /root/flashbox_config.json
  json_close_object
  # Get ifname to remove from the bridge
  uci set network.lan.ifname="$_lan_ifnames"
  uci set network.lan.proto="static"
  uci set network.lan.ipaddr="$_lan_ip"
  # Set wan and lan back to proper values
  uci set network.wan.proto="$_wan_conn_type"
  uci set network.wan6.proto="dhcpv6"
  uci set network.lan.proto="static"
  uci delete network.lan.gateway
  uci delete network.lan.dns
  /etc/init.d/miniupnpd enable
  /etc/init.d/miniupnpd start
  /etc/init.d/firewall enable
  /etc/init.d/firewall start
  /etc/init.d/dnsmasq enable
  /etc/init.d/dnsmasq start
  /etc/init.d/odhcpd enable
  /etc/init.d/odhcpd start
  uci commit network
  /etc/init.d/network restart
  /etc/init.d/odhcpd restart
}
