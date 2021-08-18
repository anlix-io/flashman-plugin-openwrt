#!/bin/sh

get_custom_hardware_model() {
	echo "ARCHERC50"
}

get_custom_hardware_version() {
	echo "V3"
}

wireless_firmware() {
  #Firmware files - Clean this in the future (use firmware api in driver)
  [ ! -e /lib/firmware/MT7628_EEPROM.bin ] && dd if=/dev/mtd6ro of=/lib/firmware/MT7628_EEPROM.bin bs=1 skip=128k count=512
  [ ! -e /lib/firmware/MT7612E_EEPROM.bin ] && dd if=/dev/mtd6ro of=/lib/firmware/MT7612E_EEPROM.bin bs=1 skip=160k count=32k
}
