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
