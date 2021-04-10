#!/bin/sh

get_custom_hardware_model() {
	echo "TL-WR2543ND"
}

custom_switch_ports() {
	case $1 in
		1) echo "switch0" ;;
		2) echo "0" ;;
		3) echo "1 2 3 4" ;;
		4) echo "9" ;;
		5) echo "4" ;;
	esac
}
