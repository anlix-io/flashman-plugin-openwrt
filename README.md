# README #

## INSTRUCTIONS ##

1. Generate a key pair or use a alredy existing key pair
	* Example: ssh-keygen -t rsa 4096
2. Always apply diffconfig with the following steps. Note: Choose proper diffconfig file if you're using OpenWRT or LEDE.
	1. `cp diffconfig <OpenWRT root directory>/.config`
	2. On OpenWRT/LEDE root directory: `make defconfig`
3. Include flash plugin `cp -r flashman-plugin <OpenWRT/LEDE root directory>/package/utils/`
4. Include custom files with `mkdir -p <OpenWRT/LEDE root directory>/files/etc && cp banner <OpenWRT/LEDE root directory>/files/etc/` 
5. Run `make menuconfig` on OpenWRT/LEDE root directory and
	1. Select target device
	2. Select flashman-plugin package on Utilities
	3. *IMPORTANT* Configure key pair path generated on step 1.
	4. *IMPORTANT* Configure public key file name generated on step 1.
	5. Configure FlashMan IP address or FQDN
	6. Change SSID, password and release ID if desired
6. Build OpenWRT/LEDE image
	1. Change to OpenWRT/LEDE root directory
	2. Always enter `make package/utils/flashman-plugin/clean`
	3. Run `make`

TODO. Feed instructions for production use

## COPYRIGHT ##

Copyright (C) 2017-2017 LAND/COPPE/UFRJ

## LICENSE ##

This is free software, licensed under the GNU General Public License v2.
The formal terms of the GPL can be found at http://www.fsf.org/licenses/
