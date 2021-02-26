#!/bin/sh

get_custom_leds_blink() {
	echo "$(ls -d /sys/class/leds/*yellow*)"
}

# Enable/disable ethernet connection on LAN physical ports when in bridge mode
set_switch_bridge_mode() {
	echo "1"
}

# Will not change ifnames if this variable is set when in bridge mode
keep_ifnames_in_bridge_mode() {
  echo "1"
}
