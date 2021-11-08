#!/bin/sh

get_custom_hardware_model() {
	echo "ARCHERC2"
}

get_custom_hardware_version() {
	echo "V1"
}

custom_switch_ports() {
	case $1 in
		1) echo "switch0" ;;
		2) echo "0" ;;
		3) echo "1 2 3 4" ;;
		4) echo "6" ;;
		5) echo "4" ;;
	esac
}

hw_offload_support() {
  echo "1"
}

wireless_firmware() {
  #Firmware files - Clean this in the future (use firmware api in driver)
  [ ! -e /lib/firmware/MT7620_AP_2T2R-4L_V15.BIN ] && dd if=/dev/mtd8ro of=/lib/firmware/MT7620_AP_2T2R-4L_V15.BIN bs=1 count=512
  [ ! -e /lib/firmware/MT7610_EEPROM.bin ] && dd if=/dev/mtd8ro of=/lib/firmware/MT7610_EEPROM.bin bs=1k skip=32 count=512
}
