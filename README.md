# README #

## INSTRUCTIONS ##

1. Generate a key pair or use a alredy existing key pair
	* Example: ssh-keygen -t rsa 4096
2. Include flash plugin `cp -r flashman-plugin <OpenWRT/LEDE root directory>/package/utils/`
3. Always apply diffconfig with the following steps. Note: Choose proper diffconfig file that applys to your router model.
	1. `cp diffconfigs/<Diffconfig file> <OpenWRT/LEDE root directory>/.config`
	2. On OpenWRT/LEDE root directory: `make defconfig`
4. Include custom files with `mkdir -p <OpenWRT/LEDE root directory>/files/etc && cp banner <OpenWRT/LEDE root directory>/files/etc/`
5. Include custom login file with `cp login.sh <OpenWRT/LEDE root directory>/package/base-files/files/bin/` 
6. Run `make menuconfig` on OpenWRT/LEDE root directory and
	1. Select target device
	2. Select flashman-plugin package on Utilities
	3. *IMPORTANT* Configure key pair path generated on step 1.
	4. *IMPORTANT* Configure public key file name generated on step 1.
	5. Configure FlashMan IP address or FQDN
	6. Change SSID, password and release ID if desired
7. Build OpenWRT/LEDE image
	1. Change to OpenWRT/LEDE root directory
	2. Always enter `make package/utils/flashman-plugin/clean`
	3. Run `make`

TODO. Feed instructions for production use

## GENERATING DIFFCONFIG FILE ##

`<OpenWRT/LEDE root directory>/scripts/diffconfig.sh > <REPO>_<BRANCH>_<COMMIT>_<TARGET>_<PROFILE>_diffconfig`

## COPYRIGHT ##

Copyright (C) 2017-2018 Anlix

## LICENSE ##

This is free software, licensed under the GNU General Public License v2.
The formal terms of the GPL can be found at http://www.fsf.org/licenses/
