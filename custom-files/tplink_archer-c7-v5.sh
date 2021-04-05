#!/bin/sh

get_custom_hardware_model() {
	echo "ARCHERC7"
}

get_custom_hardware_version() {
	echo "V5"
}

# Will not change ifnames if this variable is set when in bridge mode
keep_ifnames_in_bridge_mode() {
  echo "1"
}
