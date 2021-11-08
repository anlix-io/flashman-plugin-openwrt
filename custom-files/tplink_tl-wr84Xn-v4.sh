#!/bin/sh

wireless_firmware() {
  #Firmware files - Clean this in the future (use firmware api in driver)
  [ ! -e /lib/firmware/MT7628_EEPROM.bin ] && dd if=/dev/mtd6ro of=/lib/firmware/MT7628_EEPROM.bin bs=1 skip=128k count=512
}
