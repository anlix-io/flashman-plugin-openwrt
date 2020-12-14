#!/bin/sh

get_custom_hardware_model() {
	echo "EC220-G5"
}

get_custom_hardware_version() {
	echo "V2"
}

# Enable/disable ethernet connection on LAN physical ports when in bridge mode
set_switch_bridge_mode() {
  local _enable_bridge="$1"
  local _disable_lan_ports="$2"

  if [ "$_enable_bridge" = "y" ]
  then
    if [ "$_disable_lan_ports" = "y" ]
    then
      uci set network.@switch_vlan[0].ports='3 5t'
      uci set network.@switch_vlan[1].ports=''
    else
      uci set network.@switch_vlan[0].ports='0 1 2 3 5t'
      uci set network.@switch_vlan[1].ports=''
    fi
  else
    uci set network.@switch_vlan[0].ports='0 1 2 5t'
    uci set network.@switch_vlan[1].ports='3 5t'
  fi
}

# Will not change ifnames if this variable is set when in bridge mode
keep_ifnames_in_bridge_mode() {
  echo "1"
}
