#!/bin/sh
#
# Initialize ramips wireless driver

append DRIVERS "qcawifi"

. /lib/functions.sh
. /lib/functions/system.sh
. /usr/share/functions/device_functions.sh
. /lib/wifi/qcawifi_functions.sh
