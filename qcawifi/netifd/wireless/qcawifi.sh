#!/bin/sh


. /lib/netifd/netifd-wireless.sh
. /lib/wifi/qcawifi_functions.sh


init_wireless_driver "$@"

drv_qcawifi_init_device_config() {
	config_add_string channel hwmode htmode country macaddr
	config_add_int beacon_int chanbw frag rts txburst
	config_add_int rxantenna txantenna antenna_gain txpower distance wmm
    config_add_boolean disabled ap_isolation_enabled
}
drv_qcawifi_init_iface_config() {
	config_add_string mode bssid ssid encryption ifname 
	config_add_boolean hidden isolate disabled diversity
	config_add_string key key1 key2 key3 key4
	config_add_array maclist
	
	config_add_int maxsta dtim_period
}
drv_qcawifi_cleanup() {
	return
}
drv_qcawifi_teardown() {
	[ "${1}" == "radio0" ] && phy_name=radio0 || phy_name=radio1
	case "$phy_name" in
		radio0)
			for vif in ath0 ath01 ath02; do
				ifconfig $vif down 2>/dev/null
			done
		;;
		radio1)
			for vif in ath1 ath11 ath12; do
				ifconfig $vif down 2>/dev/null
			done
		;;
	esac
}
drv_qcawifi_setup() {
    enable_qcawifi $1 $2
}

add_driver qcawifi