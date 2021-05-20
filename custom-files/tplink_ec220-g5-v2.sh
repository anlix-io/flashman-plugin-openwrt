#!/bin/sh

get_custom_hardware_model() {
	echo "EC220-G5"
}

get_custom_hardware_version() {
	echo "V2"
}

custom_switch_ports() {
	case $1 in
		1) echo "switch0" ;;
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

hw_offload_support() {
  echo "1"
}

wireless_firmware() {
  #Firmware files - Clean this in the future (use firmware api in driver)
  [ ! -e /lib/firmware/MT7620_AP_2T2R-4L_V15.BIN ] && dd if=/dev/mtd8ro of=/lib/firmware/MT7620_AP_2T2R-4L_V15.BIN bs=1 count=512
  [ ! -e /lib/firmware/MT7612E_EEPROM.bin ] && dd if=/dev/mtd8ro of=/lib/firmware/MT7612E_EEPROM.bin bs=1k skip=32 count=1
}
