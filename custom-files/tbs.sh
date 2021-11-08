#!/bin/sh

get_custom_leds_blink() {
	local _leds=$(ls -d /sys/class/leds/*green*)
	[ -e /sys/class/leds/mt76-phy0 ] && _leds="$_leds /sys/class/leds/mt76-phy0"
	echo "$_leds"
}

get_custom_mac() {
	local _mac_address_tag=""
	local _p1

	_p1=$(uci get network.wan_eth0_2_dev.macaddr | awk '{print toupper($1)}')
	[ ! -z "$_p1" ] && _mac_address_tag=$_p1

	echo "$_mac_address_tag"
}

hw_offload_support() {
	echo "1"
}

wireless_firmware() {
	. /lib/functions.sh
	local board=$(board_name)
	#Firmware files - Clean this in the future (use firmware api in driver)
	case $board in
		dlink,dir-819-a1)
			[ ! -e /lib/firmware/MT7620_AP_2T2R-4L_V15.BIN ] && dd if=/dev/mtd0ro of=/lib/firmware/MT7620_AP_2T2R-4L_V15.BIN bs=1 skip=66080 count=512
			[ ! -e /lib/firmware/MT7610_EEPROM.bin ] && dd if=/dev/mtd0ro of=/lib/firmware/MT7610_EEPROM.bin bs=1 skip=65554 count=512
		;;
		zyxel,emg1702-t10a-a1)
			[ ! -e /lib/firmware/MT7620_AP_2T2R-4L_V15.BIN ] && dd if=/dev/mtd0ro of=/lib/firmware/MT7620_AP_2T2R-4L_V15.BIN bs=1 skip=65552 count=512
			[ ! -e /lib/firmware/MT7610_EEPROM.bin ] && dd if=/dev/mtd0ro of=/lib/firmware/MT7610_EEPROM.bin bs=1 skip=66080 count=512
		;;
	esac
}
