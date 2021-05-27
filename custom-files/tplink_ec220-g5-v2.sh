#!/bin/sh

get_custom_hardware_model() {
	echo "EC220-G5"
}

get_custom_hardware_version() {
	echo "V2"
}

custom_switch_ports() {
	case $1 in
		1) echo "switch1" ;;
		2) echo "3" ;;
		3) echo "0 1 2" ;;
		4) echo "5" ;;
		5) echo "3" ;;
	esac
}

# Will not change ifnames if this variable is set when in bridge mode
keep_ifnames_in_bridge_mode() {
  echo "1"
}
