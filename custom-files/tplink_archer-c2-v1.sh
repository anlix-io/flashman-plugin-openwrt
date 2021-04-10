#!/bin/sh

get_custom_hardware_model() {
	echo "ARCHERC2"
}

get_custom_hardware_version() {
	echo "V1"
}

custom_switch_ports() {
	case $1 in
		1) echo "switch1" ;;
		2) echo "0" ;;
		3) echo "1 2 3 4" ;;
		4) echo "6" ;;
		5) echo "4" ;;
	esac
}

# Will not change ifnames if this variable is set when in bridge mode
keep_ifnames_in_bridge_mode() {
  echo "1"
}
