#!/bin/sh

get_custom_hardware_model() {
	echo "ARCHERC6"
}

get_custom_hardware_version() {
	echo "V2US"
}

custom_switch_ports() {
	case $1 in
		1) echo "switch0" ;;
		2) echo "1" ;;
		3) echo "2 3 4 5" ;;
		4) echo "0" ;;
		5) echo "4" ;;
	esac
}

# Will not change ifnames if this variable is set when in bridge mode
keep_ifnames_in_bridge_mode() {
  echo "1"
}
