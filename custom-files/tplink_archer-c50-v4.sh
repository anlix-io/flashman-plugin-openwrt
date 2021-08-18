#!/bin/sh

get_custom_hardware_model() {
	echo "ARCHERC50"
}

get_custom_hardware_version() {
	echo "V4"
}

wireless_firmware() {
  #Firmware files - Clean this in the future (use firmware api in driver)
  [ ! -e /lib/firmware/MT7628_EEPROM.bin ] && dd if=/dev/mtd9ro of=/lib/firmware/MT7628_EEPROM.bin bs=1 count=512
  [ ! -e /lib/firmware/MT7612E_EEPROM.bin ] && dd if=/dev/mtd9ro of=/lib/firmware/MT7612E_EEPROM.bin bs=1k skip=32 count=32
}
