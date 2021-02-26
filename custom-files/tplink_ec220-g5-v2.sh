#!/bin/sh

get_custom_hardware_model() {
	echo "EC220-G5"
}

get_custom_hardware_version() {
	echo "V2"
}

# Enable/disable ethernet connection on LAN physical ports when in bridge mode
set_switch_bridge_mode() {
	echo "1"
}

# Will not change ifnames if this variable is set when in bridge mode
keep_ifnames_in_bridge_mode() {
  echo "1"
}
