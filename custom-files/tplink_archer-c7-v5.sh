#!/bin/sh

get_custom_hardware_model() {
	echo "ARCHERC7"
}

get_custom_hardware_version() {
	echo "V5"
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
