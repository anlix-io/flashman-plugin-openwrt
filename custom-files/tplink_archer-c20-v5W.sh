#!/bin/sh

get_custom_hardware_model() {
	echo "ARCHERC20"
}

get_custom_hardware_version() {
	echo "V5PRESET"
}

wireless_firmware() {
  #Firmware files - Clean this in the future (use firmware api in driver)
  [ ! -e /lib/firmware/MT7628_EEPROM.bin ] && dd if=/dev/mtd6ro of=/lib/firmware/MT7628_EEPROM.bin bs=1 skip=128k count=512
  [ ! -e /lib/firmware/MT7610_EEPROM.bin ] && dd if=/dev/mtd6ro of=/lib/firmware/MT7610_EEPROM.bin bs=1k skip=160 count=32
}
