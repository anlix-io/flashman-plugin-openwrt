#!/bin/sh

custom_switch_ports() {
	case $1 in
		1) echo "switch0" ;;
		2) echo "1" ;;
		3) echo "2 3 4 5" ;;
		4) echo "0" ;;
		5) echo "4" ;;
	esac
}
