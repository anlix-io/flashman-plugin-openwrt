#!/bin/sh

get_custom_leds_blink() {
	local _leds=$(ls -d /sys/class/leds/*green*)
	[ -e /sys/class/leds/mt76-phy0 ] && _leds="$_leds /sys/class/leds/mt76-phy0"
	echo "$_leds"
}
