#!/bin/sh

get_custom_hardware_model() {
	echo "ARCHERC20"
}

get_custom_hardware_version() {
	echo "V1"
}

get_custom_leds_blink() {
	echo "$(ls -d /sys/class/leds/*blue*)"
}

hw_offload_support() {
  echo "1"
}

wireless_firmware() {
  #Firmware files - Clean this in the future (use firmware api in driver)
  [ ! -e /lib/firmware/MT7620_AP_2T2R-4L_V15.BIN ] && dd if=/dev/mtd8ro of=/lib/firmware/MT7620_AP_2T2R-4L_V15.BIN bs=1 count=512
  [ ! -e /lib/firmware/MT7610_EEPROM.bin ] && dd if=/dev/mtd8ro of=/lib/firmware/MT7610_EEPROM.bin bs=1k skip=32 count=512
}
