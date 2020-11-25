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
