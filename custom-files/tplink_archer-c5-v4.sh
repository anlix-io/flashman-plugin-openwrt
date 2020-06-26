#!/bin/sh

get_custom_hardware_model() {
	echo "ARCHERC5"
}

get_custom_hardware_version() {
	echo "V4"
}

# Enable/disable ethernet connection on LAN physical ports when in bridge mode
set_switch_bridge_mode() {
  local _disable_lan_ports="$1"

  if [ "$_disable_lan_ports" = "y" ]
  then
    # eth0
    swconfig dev switch1 vlan 2 set ports ''
    # eth1
    swconfig dev switch1 vlan 1 set ports '4 5t'
  else
    # eth0.2
    swconfig dev switch1 vlan 2 set ports ''
    # eth0.1
    swconfig dev switch1 vlan 1 set ports '0 1 2 3 4 5t'
  fi
}

# Needs reboot to validate switch config   
needs_reboot_bridge_mode() {
  reboot
}

# Will not change ifnames if this variable is set when in bridge mode
keep_ifnames_in_bridge_mode() {
  echo "1"
}

swconfig_boot_order() {
  echo "97"
}
