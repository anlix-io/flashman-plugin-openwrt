#!/bin/sh

get_custom_leds_blink() {
	echo "$(ls -d /sys/class/leds/*orange*)"
}
