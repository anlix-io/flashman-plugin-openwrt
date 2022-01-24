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

custom_wifi_24_txpower(){
	echo "22"
}
custom_wifi_50_txpower(){
	echo "24"
}