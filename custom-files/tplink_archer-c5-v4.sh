#!/bin/sh

get_custom_hardware_model() {
	echo "ARCHERC5"
}

get_custom_hardware_version() {
	echo "V4"
}

custom_switch_ports() {
	case $1 in
		1) echo "switch1" ;;
		2) echo "4" ;;
		3) echo "0 1 2 3 " ;;
		4) echo "5" ;;
		5) echo "4" ;;
	esac
}
