#!/bin/sh
#
# Initialize ramips wireless driver

append DRIVERS "rtwifi"

. /lib/functions.sh
. /lib/functions/system.sh
. /usr/share/functions/device_functions.sh

detect_rtwifi() {
	local macaddr
	local ethmac
	local idxra

	ethmac="$(get_mac)"
	idxra=0

	for phyname in ra rai; do
	[ $( grep -c ${phyname}0 /proc/net/dev) -eq 1 ] && {
		config_get type $phyname type
		[ "$type" == "rtwifi" ] || {
			case $phyname in
				ra)
					hwmode=11g
					htmode=HT20
					pb_smart=1
					noscan=0
					macaddr=$(macaddr_add $ethmac -1)
					ssid="OpenWrt"
					idxra=0
					;;
				rai)
					hwmode=11a
					htmode=VHT80
					macaddr=$(macaddr_add $ethmac -2)
					ssid="OpenWrt"
					pb_smart=0
					noscan=1
					idxra=1
					;;
			esac
			
		uci -q batch <<-EOF
			set wireless.radio${idxra}=wifi-device
			set wireless.radio${idxra}.type=rtwifi
			set wireless.radio${idxra}.macaddr=${macaddr}
			set wireless.radio${idxra}.hwmode=$hwmode
			set wireless.radio${idxra}.channel=auto
			set wireless.radio${idxra}.txpower=100
			set wireless.radio${idxra}.htmode=$htmode
			set wireless.radio${idxra}.country=BR
			set wireless.radio${idxra}.txburst=1
			set wireless.radio${idxra}.noscan=$noscan
			set wireless.radio${idxra}.smart=$pb_smart

			set wireless.default_radio${idxra}=wifi-iface
			set wireless.default_radio${idxra}.device=radio${idxra}
			set wireless.default_radio${idxra}.network=lan
			set wireless.default_radio${idxra}.mode=ap
			set wireless.default_radio${idxra}.ssid=${ssid}
			set wireless.default_radio${idxra}.encryption=none
EOF
		uci -q commit wireless
		}
	}
	done
}
