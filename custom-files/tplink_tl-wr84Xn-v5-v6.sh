#!/bin/sh

get_custom_leds_blink() {
	echo "$(ls -d /sys/class/leds/*orange*)"
}

wireless_firmware() {
  #Firmware files - Clean this in the future (use firmware api in driver)
  [ ! -e /lib/firmware/MT7628_EEPROM.bin ] && dd if=/dev/mtd5ro of=/lib/firmware/MT7628_EEPROM.bin bs=1 count=512
}
