#!/bin/sh
#
# Copyright (c) 2017 Qualcomm Technologies, Inc.
#
# All Rights Reserved.
# Confidential and Proprietary - Qualcomm Technologies, Inc.
#
# Copyright (c) 2014, 2016, The Linux Foundation. All rights reserved.
#
#

. /lib/functions.sh

wlanconfig() {
	[ -n "${DEBUG}" ] && echo wlanconfig "$@"
	/usr/sbin/wlanconfig "$@"
}

iwconfig() {
	[ -n "${DEBUG}" ] && echo iwconfig "$@"
	/usr/sbin/iwconfig "$@"
}

iwpriv() {
	[ -n "${DEBUG}" ] && echo iwpriv "$@"
	/usr/sbin/iwpriv "$@"
}

find_qcawifi_phy() {
	local device="$1"

	local macaddr="$(config_get "$device" macaddr | tr 'A-Z' 'a-z')"
	config_get phy "$device" phy
	[ -z "$phy" -a -n "$macaddr" ] && {
		cd /sys/class/net
		for phy in $(ls -d radio* 2>&-); do
			[ "$macaddr" = "$(cat /sys/class/net/${phy}/address)" ] || continue
			config_set "$device" phy "$phy"
			break
		done
		config_get phy "$device" phy
	}
	[ -n "$phy" -a -d "/sys/class/net/$phy" ] || {
		echo "phy for wifi device $1 not found"
		return 1
	}
	[ -z "$macaddr" ] && {
		config_set "$device" macaddr "$(cat /sys/class/net/${phy}/address)"
	}
	return 0
}

# The country ID is set at the radio level. When the driver attaches the radio,
# it sets the default country ID to 840 (US STA). This is because the desired
# VAP modes are not known at radio attach time, and STA functionality is the
# common unit of 802.11 operation.
# If the user desires any of the VAPs to be in AP mode, then we set a new
# default of 843 (US AP with TDWR) from this script. Even if any of the other
# VAPs are in non-AP modes like STA or Monitor, the stricter default of 843
# will apply.
# No action is required here if none of the VAPs are in AP mode.
set_default_country() {
	local device="$1"
	local mode

	find_qcawifi_phy "$device" || return 1
	config_get phy "$device" phy

	config_get vifs "$device" vifs
	for vif in $vifs; do
		config_get_bool disabled "$vif" disabled 0
		[ $disabled = 0 ] || continue

		config_get mode "$vif" mode
		case "$mode" in
			ap|wrap|ap_monitor|ap_smart_monitor|ap_lp_iot)
				iwpriv "$phy" setCountryID 843
				return 0;
			;;
		*) ;;
		esac
	done

	return 0
}

config_low_targ_clkspeed() {
        local board_name
        [ -f /tmp/sysinfo/board_name ] && {
                board_name=$(cat /tmp/sysinfo/board_name)
        }

        case "$board_name" in
                ap147 | ap151)
                   echo "true"
                ;;
                *) echo "false"
                ;;
        esac
}

# configure tx queue fc_buf_max
config_tx_fc_buf() {
	local phy="$1"
	local board_name
	[ -f /tmp/sysinfo/board_name ] && {
		board_name=$(cat /tmp/sysinfo/board_name)
	}
	memtotal=$(grep MemTotal /proc/meminfo | awk '{print $2}')

	case "$board_name" in
		ap-dk*)
			if [ $memtotal -le 131072 ]; then
				# 4MB tx queue max buffer size
				iwpriv "$phy" fc_buf_max 4096
				iwpriv "$phy" fc_q_max 512
				iwpriv "$phy" fc_q_min 32
			elif [ $memtotal -le 256000 ]; then
				# 8MB tx queue max buffer size
				iwpriv "$phy" fc_buf_max 8192
				iwpriv "$phy" fc_q_max 1024
				iwpriv "$phy" fc_q_min 64
			fi
				# default value from code memsize > 256MB
		;;

		*)
		;;
	esac
}

_disable_qcawifi() {
	local device="$1"
	local parent
	local retval=0
	local recover="$2"

	echo "$DRIVERS disable radio $1" >/dev/console

	find_qcawifi_phy "$device" >/dev/null || return 1

	# If qrfs is disabled in enable_qcawifi(),need to enable it
	if [ -f /var/qrfs_disabled_by_wifi ] && [ $(cat /var/qrfs_disabled_by_wifi) == 1 ]; then
		echo "1" > /proc/qrfs/enable
		echo "0" > /var/qrfs_disabled_by_wifi
	fi

	config_get phy "$device" phy

	set_wifi_down "$device"

	include /lib/network
	cd /sys/class/net
	for dev in *; do
		[ -f /sys/class/net/${dev}/parent ] && { \
			local parent=$(cat /sys/class/net/${dev}/parent)
			[ -n "$parent" -a "$parent" = "$device" ] && { \
				[ -f "/var/run/hostapd-${dev}.lock" ] && { \
					wpa_cli -g /var/run/hostapd/global raw REMOVE ${dev}
					rm /var/run/hostapd-${dev}.lock
				}
				[ -f "/var/run/wpa_supplicant-${dev}.lock" ] && { \
					wpa_cli -g /var/run/wpa_supplicantglobal  interface_remove  ${dev}
					rm /var/run/wpa_supplicant-${dev}.lock
				}
				[ -f "/var/run/wapid-${dev}.conf" ] && { \
					kill "$(cat "/var/run/wifi-${dev}.pid")"
				}
				ifconfig "$dev" down
				unbridge "$dev"
				if [ -z "$recover" ] || [ "$recover" -eq "0" ]; then
				    wlanconfig "$dev" destroy
				fi
			}
			[ -f /var/run/hostapd_cred_${device}.bin ] && { \
				rm /var/run/hostapd_cred_${device}.bin
			}
		}
	done

	return 0
}

disable_qcawifi() {
	local device="$1"
	lock /var/run/wifilock
	_disable_qcawifi "$device" $2
	lock -u /var/run/wifilock
}

enable_qcawifi() {
	echo "enable_qcawifi \$1=$1"
	local device="$1"
	local count=0 # hostapd count
	local num_radio_instamode=0
	local recover="$2"

	find_qcawifi_phy "$device" || return 1

	echo "enable_qcawifi \$1=$1 POST FIND"
	lock /var/run/wifilock

	echo "enable_qcawifi \$1=$1 POST LOCK"
	config_get phy "$device" phy

	config_get preCACEn "$device" preCACEn
	[ -n "$preCACEn" ] && iwpriv "$phy" preCACEn "$preCACEn"

	config_get country "$device" country
	if [ -z "$country" ]; then
		if ! set_default_country $device; then
			lock -u /var/run/wifilock
			return 1
		fi
	else
		# If the country parameter is a number (either hex or decimal), we
		# assume it's a regulatory domain - i.e. we use iwpriv setCountryID.
		# Else we assume it's a country code - i.e. we use iwpriv setCountry.
		case "$country" in
			[0-9]*)
				iwpriv "$phy" setCountryID "$country"
			;;
			*)
				[ -n "$country" ] && iwpriv "$phy" setCountry "$country"
			;;
		esac
	fi
	config_get channel "$device" channel
	config_get vifs "$device" vifs
	config_get txpower "$device" txpower

	# wifi's config_cb duplicates last wifi-iface entry ; deduplicating now
	vifs=$(echo "$vifs" | tr " " "\n" | sort -u | tr "\n" " ") 
	
	[ auto = "$channel" ] && channel=0

	config_get_bool antdiv "$device" diversity
	config_get antrx "$device" rxantenna
	config_get anttx "$device" txantenna
	config_get_bool softled "$device" softled
	config_get antenna "$device" antenna
	config_get distance "$device" distance

	[ -n "$antdiv" ] && echo "antdiv option not supported on this driver"
	[ -n "$antrx" ] && echo "antrx option not supported on this driver"
	[ -n "$anttx" ] && echo "anttx option not supported on this driver"
	[ -n "$softled" ] && echo "softled option not supported on this driver"
	[ -n "$antenna" ] && echo "antenna option not supported on this driver"
	[ -n "$distance" ] && echo "distance option not supported on this driver"

	# Shutting up the log from radio1 (the only one with this debug option)
	[ "$phy" = "radio1" ] && iwpriv "$phy" dbglog_ratelim 1 

	# Advanced QCA wifi per-radio parameters configuration
	config_get txchainmask "$device" txchainmask
	[ -n "$txchainmask" ] && iwpriv "$phy" txchainmask "$txchainmask"

	config_get rxchainmask "$device" rxchainmask
	[ -n "$rxchainmask" ] && iwpriv "$phy" rxchainmask "$rxchainmask"

	config_get regdomain "$device" regdomain
	[ -n "$regdomain" ] && iwpriv "$phy" setRegdomain "$regdomain"

	config_get AMPDU "$device" AMPDU
	[ -n "$AMPDU" ] && iwpriv "$phy" AMPDU "$AMPDU"

	config_get ampdudensity "$device" ampdudensity
	[ -n "$ampdudensity" ] && iwpriv "$phy" ampdudensity "$ampdudensity"

	config_get_bool AMSDU "$device" AMSDU
	[ -n "$AMSDU" ] && iwpriv "$phy" AMSDU "$AMSDU"

	config_get AMPDULim "$device" AMPDULim
	[ -n "$AMPDULim" ] && iwpriv "$phy" AMPDULim "$AMPDULim"

	config_get AMPDUFrames "$device" AMPDUFrames
	[ -n "$AMPDUFrames" ] && iwpriv "$phy" AMPDUFrames "$AMPDUFrames"

	config_get AMPDURxBsize "$device" AMPDURxBsize
	[ -n "$AMPDURxBsize" ] && iwpriv "$phy" AMPDURxBsize "$AMPDURxBsize"

	config_get_bool bcnburst "$device" bcnburst 0
	[ "$bcnburst" -gt 0 ] && iwpriv "$phy" set_bcnburst "$bcnburst"

	config_get set_smart_antenna "$device" set_smart_antenna
	[ -n "$set_smart_antenna" ] && iwpriv "$phy" setSmartAntenna "$set_smart_antenna"

	config_get current_ant "$device" current_ant
	[ -n  "$current_ant" ] && iwpriv "$phy" current_ant "$current_ant"

	config_get default_ant "$device" default_ant
	[ -n "$default_ant" ] && iwpriv "$phy" default_ant "$default_ant"

	config_get ant_retrain "$device" ant_retrain
	[ -n "$ant_retrain" ] && iwpriv "$phy" ant_retrain "$ant_retrain"

	config_get retrain_interval "$device" retrain_interval
	[ -n "$retrain_interval" ] && iwpriv "$phy" retrain_interval "$retrain_interval"

	config_get retrain_drop "$device" retrain_drop
	[ -n "$retrain_drop" ] && iwpriv "$phy" retrain_drop "$retrain_drop"

	config_get ant_train "$device" ant_train
	[ -n "$ant_train" ] && iwpriv "$phy" ant_train "$ant_train"

	config_get ant_trainmode "$device" ant_trainmode
	[ -n "$ant_trainmode" ] && iwpriv "$phy" ant_trainmode "$ant_trainmode"

	config_get ant_traintype "$device" ant_traintype
	[ -n "$ant_traintype" ] && iwpriv "$phy" ant_traintype "$ant_traintype"

	config_get ant_pktlen "$device" ant_pktlen
	[ -n "$ant_pktlen" ] && iwpriv "$phy" ant_pktlen "$ant_pktlen"

	config_get ant_numpkts "$device" ant_numpkts
	[ -n "$ant_numpkts" ] && iwpriv "$phy" ant_numpkts "$ant_numpkts"

	config_get ant_numitr "$device" ant_numitr
	[ -n "$ant_numitr" ] && iwpriv "$phy" ant_numitr "$ant_numitr"

	config_get ant_train_thres "$device" ant_train_thres
	[ -n "$ant_train_thres" ] && iwpriv "$phy" train_threshold "$ant_train_thres"

	config_get ant_train_min_thres "$device" ant_train_min_thres
	[ -n "$ant_train_min_thres" ] && iwpriv "$phy" ant_train_min_thres "$ant_train_min_thres"

	config_get ant_traffic_timer "$device" ant_traffic_timer
	[ -n "$ant_traffic_timer" ] && iwpriv "$phy" traffic_timer "$ant_traffic_timer"

	config_get dcs_enable "$device" dcs_enable
	[ -n "$dcs_enable" ] && iwpriv "$phy" dcs_enable "$dcs_enable"

	config_get dcs_coch_int "$device" dcs_coch_int
	[ -n "$dcs_coch_int" ] && iwpriv "$phy" set_dcs_coch_int "$dcs_coch_int"

	config_get dcs_errth "$device" dcs_errth
	[ -n "$dcs_errth" ] && iwpriv "$phy" set_dcs_errth "$dcs_errth"

	config_get dcs_phyerrth "$device" dcs_phyerrth
	[ -n "$dcs_phyerrth" ] && iwpriv "$phy" set_dcs_phyerrth "$dcs_phyerrth"

	config_get dcs_usermaxc "$device" dcs_usermaxc
	[ -n "$dcs_usermaxc" ] && iwpriv "$phy" set_dcs_usermaxc "$dcs_usermaxc"

	config_get dcs_debug "$device" dcs_debug
	[ -n "$dcs_debug" ] && iwpriv "$phy" set_dcs_debug "$dcs_debug"

	config_get set_ch_144 "$device" set_ch_144
	[ -n "$set_ch_144" ] && iwpriv "$phy" setCH144 "$set_ch_144"

	config_get eppovrd_ch_144 "$device" eppovrd_ch_144
	[ -n "$eppovrd_ch_144" ] && iwpriv "$phy" setCH144EppOvrd "$eppovrd_ch_144"

	config_get_bool ani_enable "$device" ani_enable
	[ -n "$ani_enable" ] && iwpriv "$phy" ani_enable "$ani_enable"

	config_get_bool acs_bkscanen "$device" acs_bkscanen
	[ -n "$acs_bkscanen" ] && iwpriv "$phy" acs_bkscanen "$acs_bkscanen"

	config_get acs_scanintvl "$device" acs_scanintvl
	[ -n "$acs_scanintvl" ] && iwpriv "$phy" acs_scanintvl "$acs_scanintvl"

	config_get acs_rssivar "$device" acs_rssivar
	[ -n "$acs_rssivar" ] && iwpriv "$phy" acs_rssivar "$acs_rssivar"

	config_get acs_chloadvar "$device" acs_chloadvar
	[ -n "$acs_chloadvar" ] && iwpriv "$phy" acs_chloadvar "$acs_chloadvar"

	config_get acs_lmtobss "$device" acs_lmtobss
	[ -n "$acs_lmtobss" ] && iwpriv "$phy" acs_lmtobss "$acs_lmtobss"

	config_get acs_ctrlflags "$device" acs_ctrlflags
	[ -n "$acs_ctrlflags" ] && iwpriv "$phy" acs_ctrlflags "$acs_ctrlflags"

	config_get acs_dbgtrace "$device" acs_dbgtrace
	[ -n "$acs_dbgtrace" ] && iwpriv "$phy" acs_dbgtrace "$acs_dbgtrace"

	config_get_bool dscp_ovride "$device" dscp_ovride
	[ -n "$dscp_ovride" ] && iwpriv "$phy" set_dscp_ovride "$dscp_ovride"

	config_get reset_dscp_map "$device" reset_dscp_map
	[ -n "$reset_dscp_map" ] && iwpriv "$phy" reset_dscp_map "$reset_dscp_map"

	config_get dscp_tid_map "$device" dscp_tid_map
	[ -n "$dscp_tid_map" ] && iwpriv "$phy" set_dscp_tid_map $dscp_tid_map

        #Default enable IGMP overide & TID=6
	iwpriv "$phy" sIgmpDscpOvrid 1
	iwpriv "$phy" sIgmpDscpTidMap 6

	config_get_bool igmp_dscp_ovride "$device" igmp_dscp_ovride
	[ -n "$igmp_dscp_ovride" ] && iwpriv "$phy" sIgmpDscpOvrid "$igmp_dscp_ovride"

	config_get igmp_dscp_tid_map "$device" igmp_dscp_tid_map
	[ -n "$igmp_dscp_tid_map" ] && iwpriv "$phy" sIgmpDscpTidMap "$igmp_dscp_tid_map"

	config_get_bool hmmc_dscp_ovride "$device" hmmc_dscp_ovride
	[ -n "$hmmc_dscp_ovride" ] && iwpriv "$phy" sHmmcDscpOvrid "$hmmc_dscp_ovride"

	config_get hmmc_dscp_tid_map "$device" hmmc_dscp_tid_map
	[ -n "$hmmc_dscp_tid_map" ] && iwpriv "$phy" sHmmcDscpTidMap "$hmmc_dscp_tid_map"

	config_get_bool blk_report_fld "$device" blk_report_fld
	[ -n "$blk_report_fld" ] && iwpriv "$phy" setBlkReportFld "$blk_report_fld"

	config_get_bool drop_sta_query "$device" drop_sta_query
	[ -n "$drop_sta_query" ] && iwpriv "$phy" setDropSTAQuery "$drop_sta_query"

	config_get_bool burst "$device" burst
	[ -n "$burst" ] && iwpriv "$phy" burst "$burst"

	config_get burst_dur "$device" burst_dur
	[ -n "$burst_dur" ] && iwpriv "$phy" burst_dur "$burst_dur"

	config_get TXPowLim2G "$device" TXPowLim2G
	[ -n "$TXPowLim2G" ] && iwpriv "$phy" TXPowLim2G "$TXPowLim2G"

	config_get TXPowLim5G "$device" TXPowLim5G
	[ -n "$TXPowLim5G" ] && iwpriv "$phy" TXPowLim5G "$TXPowLim5G"

	config_get_bool enable_ol_stats "$device" enable_ol_stats
	[ -n "$enable_ol_stats" ] && iwpriv "$phy" enable_ol_stats "$enable_ol_stats"

	config_get emiwar80p80 "$device" emiwar80p80
	[ -n "$emiwar80p80" ] && iwpriv "$phy" emiwar80p80 "$emiwar80p80"

	config_get_bool rst_tso_stats "$device" rst_tso_stats
	[ -n "$rst_tso_stats" ] && iwpriv "$phy" rst_tso_stats "$rst_tso_stats"

	config_get_bool rst_lro_stats "$device" rst_lro_stats
	[ -n "$rst_lro_stats" ] && iwpriv "$phy" rst_lro_stats "$rst_lro_stats"

	config_get_bool rst_sg_stats "$device" rst_sg_stats
	[ -n "$rst_sg_stats" ] && iwpriv "$phy" rst_sg_stats "$rst_sg_stats"

	config_get_bool set_fw_recovery "$device" set_fw_recovery
	[ -n "$set_fw_recovery" ] && iwpriv "$phy" set_fw_recovery "$set_fw_recovery"

	config_get_bool allowpromisc "$device" allowpromisc
	[ -n "$allowpromisc" ] && iwpriv "$phy" allowpromisc "$allowpromisc"

	config_get set_sa_param "$device" set_sa_param
	[ -n "$set_sa_param" ] && iwpriv "$phy" set_sa_param $set_sa_param

	config_get_bool aldstats "$device" aldstats
	[ -n "$aldstats" ] && iwpriv "$phy" aldstats "$aldstats"

	config_get macaddr "$device" macaddr
	[ -n "$macaddr" ] && iwpriv "$phy" setHwaddr "$macaddr"

	config_get max_radio_sta "$device" max_radio_sta
	[ -n "$max_radio_sta" ] && iwpriv "$phy" max_radio_sta "$max_radio_sta"

	config_get promisc "$device" promisc
	[ -n "$promisc" ] && iwpriv "$phy" promisc $promisc

	config_get mode0 "$device" mode0
	[ -n "$mode0" ] && iwpriv "$phy" fc_buf_min 2501

	config_get mode1 "$device" mode1
	[ -n "$mode1" ] && iwpriv "$phy" fc_buf_min 0

	handle_aggr_burst() {
		local value="$1"
		[ -n "$value" ] && iwpriv "$phy" aggr_burst $value
	}

	config_list_foreach "$device" aggr_burst handle_aggr_burst

	config_get_bool block_interbss "$device" block_interbss
	[ -n "$block_interbss" ] && iwpriv "$phy" block_interbss "$block_interbss"

	config_get set_pmf "$device" set_pmf
	[ -n "$set_pmf" ] && iwpriv "$phy" set_pmf "${set_pmf}"

	config_get txbf_snd_int "$device" txbf_snd_int 100
	[ -n "$txbf_snd_int" ] && iwpriv "$phy" txbf_snd_int "$txbf_snd_int"

	config_get mcast_echo "$device" mcast_echo
	[ -n "$mcast_echo" ] && iwpriv "$phy" mcast_echo "${mcast_echo}"

	config_get obss_rssi_th "$device" obss_rssi_th 35
	[ -n "$obss_rssi_th" ] && iwpriv "$phy" obss_rssi_th "${obss_rssi_th}"

	config_get obss_rx_rssi_th "$device" obss_rx_rssi_th 35
	[ -n "$obss_rx_rssi_th" ] && iwpriv "$phy" obss_rxrssi_th "${obss_rx_rssi_th}"

	config_get acs_txpwr_opt "$device" acs_txpwr_opt
	[ -n "$acs_txpwr_opt" ] && iwpriv "$phy" acs_txpwr_opt "${acs_txpwr_opt}"

	config_get obss_long_slot "$device" obss_long_slot
	[ -n "$obss_long_slot" ] && iwpriv "$phy" obss_long_slot "${obss_long_slot}"

	config_get staDFSEn "$device" staDFSEn
	[ -n "$staDFSEn" ] && iwpriv "$phy" staDFSEn "${staDFSEn}"

        config_get dbdc_enable "$device" dbdc_enable
        [ -n "$dbdc_enable" ] && iwpriv "$phy" dbdc_enable "${dbdc_enable}"

        config_get client_mcast "$device" client_mcast
        [ -n "$client_mcast" ] && iwpriv "$phy" client_mcast "${client_mcast}"

        config_get pas_scanen "$device" pas_scanen
        [ -n "$pas_scanen" ] && iwpriv "$phy" pas_scanen "${pas_scanen}"

        config_get delay_stavapup "$device" delay_stavapup
        [ -n "$delay_stavapup" ] && iwpriv "$phy" delay_stavapup "${delay_stavapup}"

        config_get tid_override_queue_map "$device" tid_override_queue_map
        [ -n "$tid_override_queue_map" ] && iwpriv "$phy" queue_map "${tid_override_queue_map}"

        config_get channel_block_mode "$device" channel_block_mode
        [ -n "$channel_block_mode" ] && iwpriv "$phy" acs_bmode "${channel_block_mode}"

        config_get no_vlan "$device" no_vlan
        [ -n "$no_vlan" ] && iwpriv "$phy" no_vlan "${no_vlan}"

        config_get btcoex_wl_pri "$device" btcoex_wl_pri
        [ -n "$btcoex_wl_pri" ] && iwpriv "$phy" btcoex_wl_pri "${btcoex_wl_pri}"

        config_get btcoex_enable "$device" btcoex_enable
        [ -n "$btcoex_enable" ] && iwpriv "$phy" btcoex_enable "${btcoex_enable}"

        config_get btcoex_dc "$device" btcoex_dc
        [ -n "$btcoex_dc" ] && iwpriv "$phy" btcoex_dc "${btcoex_dc}"

        config_get ul_hyst "$device" ul_hyst
        [ -n "$ul_hyst" ] && iwpriv "$phy" ul_hyst "${ul_hyst}"

        config_get discon_time qcawifi discon_time 10
        [ -n "$discon_time" ] && iwpriv "$phy" discon_time "${discon_time}"

        config_get reconfig_time qcawifi reconfig_time 60
        [ -n "$reconfig_time" ] && iwpriv "$phy" reconfig_time "${reconfig_time}"

        config_get alwaysprimary qcawifi alwaysprimary
        [ -n "$alwaysprimary" ] && iwpriv "$phy" alwaysprimary "${alwaysprimary}"

	if [ -f /lib/wifi/wifi_nss_olcfg ]; then
		nss_wifi_olcfg="$(cat /lib/wifi/wifi_nss_olcfg)"
		if [ $nss_wifi_olcfg != 0 ]; then
			config_get hwmode "$device" hwmode auto
			case "$hwmode" in
				*ng)
					iwpriv "$phy" fc_buf0_max 5120
					iwpriv "$phy" fc_buf1_max 8192
					iwpriv "$phy" fc_buf2_max 12288
					iwpriv "$phy" fc_buf3_max 16384
					;;
				*ac)
					iwpriv "$phy" fc_buf0_max 8192
					iwpriv "$phy" fc_buf1_max 16384
					iwpriv "$phy" fc_buf2_max 24576
					iwpriv "$phy" fc_buf3_max 32768
					;;
				*)
					iwpriv "$phy" fc_buf0_max 5120
					iwpriv "$phy" fc_buf1_max 8192
					iwpriv "$phy" fc_buf2_max 12288
					iwpriv "$phy" fc_buf3_max 16384
					;;
			esac
		fi
	fi

	config_tx_fc_buf "$phy"

	# Enable RPS and disable qrfs, if rxchainmask is 15 for some platforms
	disable_qrfs_wifi=0
	enable_rps_wifi=0
	if [ $(iwpriv "$phy" get_rxchainmask | awk -F ':' '{ print $2 }') == 15 ]; then
		disable_qrfs_wifi=1
		enable_rps_wifi=1
	fi

	for vif in $vifs; do

		config_get_bool disabled "$vif" disabled 0
		[ $disabled = 0 ] || continue
		
		local start_hostapd=
		config_get mode "$vif" mode
		config_get enc "$vif" encryption "none"

		case "$enc" in
			mixed*|psk*|wpa*|8021x)
				start_hostapd=1
				config_get key "$vif" key
			;;
		esac

		case "$mode" in
			ap|wrap)
				if [ -n "$start_hostapd" ] && [ $count -lt 2 ] && eval "type hostapd_config_multi_cred" 2>/dev/null >/dev/null; then
					hostapd_config_multi_cred "$vif"
					count=$(($count + 1))
				fi
	  			;;
                esac
	done

	for vif in $vifs; do
		
		config_get_bool disabled "$vif" disabled 0
		[ $disabled = 0 ] || continue
		
		local start_hostapd= vif_txpower= nosbeacon= wlanaddr=""
		local wlanmode
		config_get ifname "$vif" ifname
		config_get enc "$vif" encryption "none"
		config_get eap_type "$vif" eap_type
		config_get mode "$vif" mode
		wlanmode=$mode

		if [ -f /sys/class/net/$device/ciphercaps ]
		then
			case "$enc" in
				*gcmp*)
					echo "enc:GCMP" >&2
					cat /sys/class/net/$device/ciphercaps | grep -i "gcmp"
					if [ $? -ne 0 ]
					then
						echo "enc:GCMP is Not Supported on Radio" >&2
						continue
					fi
					;;
				*ccmp-256*)
					echo "enc:CCMP-256" >&2
					cat /sys/class/net/$device/ciphercaps | grep -i "ccmp-256"
					if [ $? -ne 0 ]
					then
						echo "enc:CCMP-256 is Not Supported on Radio" >&2
						continue
					fi
					;;
			esac
		fi

		[ "$wlanmode" = "ap_monitor" ] && wlanmode="specialvap"
		[ "$wlanmode" = "ap_smart_monitor" ] && wlanmode="smart_monitor"
		[ "$wlanmode" = "ap_lp_iot" ] && wlanmode="lp_iot_mode"

		case "$mode" in
			sta)
				nosbeacon="1"
				config_get qwrap_enable "$device" qwrap_enable 0
				[ $qwrap_enable -gt 0 ] && wlanaddr="00:00:00:00:00:00"
				;;
			adhoc)
				config_get_bool nosbeacon "$vif" sw_merge 1
				;;
		esac

		[ "$nosbeacon" = 1 ] || nosbeacon=""
		echo wlanconfig "$ifname" create wlandev "$phy" wlanmode "$wlanmode" ${wlanaddr:+wlanaddr "$wlanaddr"} ${nosbeacon:+nosbeacon}  > /dev/console
		if [ -z "$recover" ] || [ "$recover" -eq "0" ]; then
			ifname=$(/usr/sbin/wlanconfig "$ifname" create wlandev "$phy" wlanmode "$wlanmode" ${wlanaddr:+wlanaddr "$wlanaddr"} ${nosbeacon:+nosbeacon})
			[ $? -ne 0 ] && {
				echo "enable_qcawifi($device): Failed to set up $mode vif $ifname" > /dev/console
				continue
			}
			config_set "$vif" ifname "$ifname"
		fi

		# ROMEU - the whole debug mask , except IEEE80211_MSG_ELEMID and SCANENTRY
		#iwpriv $ifname dbgLVL 0xfdfffff7 

		config_get hwmode "$device" hwmode auto
		config_get htmode "$device" htmode auto

		pureg=0
		case "$hwmode:$htmode" in
		# The parsing stops at the first match so we need to make sure
		# these are in the right orders (most generic at the end)
			*ng:HT20) hwmode=11NGHT20;;
			*ng:HT40-) hwmode=11NGHT40MINUS;;
			*ng:HT40+) hwmode=11NGHT40PLUS;;
			*ng:HT40) hwmode=11NGHT40;;
			*ng:*) hwmode=11NGHT20;;
			*na:HT20) hwmode=11NAHT20;;
			*na:HT40-) hwmode=11NAHT40MINUS;;
			*na:HT40+) hwmode=11NAHT40PLUS;;
			*na:HT40) hwmode=11NAHT40;;
			*na:*) hwmode=11NAHT40;;
			*ac:*T20) hwmode=11ACVHT20;;
			*ac:*T40+) hwmode=11ACVHT40PLUS;;
			*ac:*T40-) hwmode=11ACVHT40MINUS;;
			*ac:*T40) hwmode=11ACVHT40;;
			*ac:*) hwmode=11ACVHT80;;
			*b:*) hwmode=11B;;
			*bg:*) hwmode=11G;;
			*g:*) hwmode=11G; pureg=1;;
			*a:*) hwmode=11A;;
			*) hwmode=AUTO;;
		esac
		iwpriv "$ifname" mode "$hwmode"
		[ $pureg -gt 0 ] && iwpriv "$ifname" pureg "$pureg"

		config_get cfreq2 "$vif" cfreq2
		[ -n "$cfreq2" -a "$htmode" = "HT80_80" ] && iwpriv "$ifname" cfreq2 "$cfreq2"

		config_get puren "$vif" puren
		[ -n "$puren" ] && iwpriv "$ifname" puren "$puren"

		iwconfig "$ifname" channel "$channel" >/dev/null 2>/dev/null

		config_get_bool hidden "$vif" hidden 0
		iwpriv "$ifname" hide_ssid "$hidden"

                config_get_bool dynamicbeacon "$vif" dynamicbeacon 0
                [ $hidden = 1 ] && iwpriv "$ifname" dynamicbeacon "$dynamicbeacon"

                config_get db_rssi_thr "$vif" db_rssi_thr
                [ -n "$db_rssi_thr" ] && iwpriv "$ifname" db_rssi_thr "$db_rssi_thr"

                config_get db_timeout "$vif" db_timeout
                [ -n "$db_timeout" ] && iwpriv "$ifname" db_timeout "$db_timeout"

                config_get nrshareflag "$vif" nrshareflag
                [ -n "$nrshareflag" ] && iwpriv "$ifname" nrshareflag "$nrshareflag"

		config_get_bool shortgi "$vif" shortgi 1
		[ -n "$shortgi" ] && iwpriv "$ifname" shortgi "${shortgi}"

		config_get_bool disablecoext "$vif" disablecoext
		[ -n "$disablecoext" ] && iwpriv "$ifname" disablecoext "${disablecoext}"

		config_get chwidth "$vif" chwidth
		[ -n "$chwidth" ] && iwpriv "$ifname" chwidth "${chwidth}"

		iwpriv "$ifname" wds 0 >/dev/null 2>&1

		config_get  backhaul "$vif" backhaul 0
                iwpriv "$ifname" backhaul "$backhaul" >/dev/null 2>&1

		config_get TxBFCTL "$vif" TxBFCTL
		[ -n "$TxBFCTL" ] && iwpriv "$ifname" TxBFCTL "$TxBFCTL"

		config_get bintval "$vif" bintval
		[ -n "$bintval" ] && iwpriv "$ifname" bintval "$bintval"

		config_get_bool countryie "$vif" countryie
		[ -n "$countryie" ] && iwpriv "$ifname" countryie "$countryie"

		case "$enc" in
			none)
				# We start hostapd in open mode also
				start_hostapd=1
			;;
			wep*)
				case "$enc" in
					*mixed*)  iwpriv "$ifname" authmode 4;;
					*shared*) iwpriv "$ifname" authmode 2;;
					*)        iwpriv "$ifname" authmode 1;;
				esac
				for idx in 1 2 3 4; do
					config_get key "$vif" "key${idx}"
					[ -n "$key" ] && iwconfig "$ifname"  enc "[$idx]" "$key"
				done
				config_get key "$vif" key
				key="${key:-1}"
				case "$key" in
					[1234]) iwconfig "$ifname" enc "[$key]";;
					*) iwconfig "$ifname" enc "$key";;
				esac
			;;
			mixed*|psk*|wpa*|8021x)
				start_hostapd=1
				config_get key "$vif" key
			;;
			wapi*)
				start_wapid=1
				config_get key "$vif" key
			;;
		esac

		case "$mode" in
			sta|adhoc)
				config_get addr "$vif" bssid
				[ -z "$addr" ] || {
					iwconfig "$ifname" ap "$addr"
				}
			;;
		esac

		config_get_bool uapsd "$vif" uapsd 1
		iwpriv "$ifname" uapsd "$uapsd"
		
		# "son" is the proprietary mesh solution for qualcomm devices
		iwpriv "$ifname" son 0 

		config_get mcast_rate "$vif" mcast_rate
		[ -n "$mcast_rate" ] && iwpriv "$ifname" mcast_rate "${mcast_rate%%.*}"

		config_get powersave "$vif" powersave
		[ -n "$powersave" ] && iwpriv "$ifname" powersave "${powersave}"

		config_get_bool ant_ps_on "$vif" ant_ps_on
		[ -n "$ant_ps_on" ] && iwpriv "$ifname" ant_ps_on "${ant_ps_on}"

		config_get ps_timeout "$vif" ps_timeout
		[ -n "$ps_timeout" ] && iwpriv "$ifname" ps_timeout "${ps_timeout}"

		config_get mcastenhance "$vif" mcastenhance
		[ -n "$mcastenhance" ] && iwpriv "$ifname" mcastenhance "${mcastenhance}"

		config_get disable11nmcs "$vif" disable11nmcs
		[ -n "$disable11nmcs" ] && iwpriv "$ifname" disable11nmcs "${disable11nmcs}"

		config_get conf_11acmcs "$vif" conf_11acmcs
		[ -n "$conf_11acmcs" ] && iwpriv "$ifname" conf_11acmcs "${conf_11acmcs}"

		config_get metimer "$vif" metimer
		[ -n "$metimer" ] && iwpriv "$ifname" metimer "${metimer}"

		config_get metimeout "$vif" metimeout
		[ -n "$metimeout" ] && iwpriv "$ifname" metimeout "${metimeout}"

		config_get_bool medropmcast "$vif" medropmcast
		[ -n "$medropmcast" ] && iwpriv "$ifname" medropmcast "${medropmcast}"

		config_get me_adddeny "$vif" me_adddeny
		[ -n "$me_adddeny" ] && iwpriv "$ifname" me_adddeny ${me_adddeny}

		#support independent repeater mode
		config_get vap_ind "$vif" vap_ind
		[ -n "$vap_ind" ] && iwpriv "$ifname" vap_ind "${vap_ind}"

		#support extender ap & STA
		config_get extap "$vif" extap 1
		[ -n "$extap" ] && iwpriv "$ifname" extap "${extap}"

		config_get scanband "$vif" scanband
		[ -n "$scanband" ] && iwpriv "$ifname" scanband "${scanband}"

		config_get periodicScan "$vif" periodicScan
		[ -n "$periodicScan" ] && iwpriv "$ifname" periodicScan "${periodicScan}"

		config_get frag "$vif" frag
		[ -n "$frag" ] && iwconfig "$ifname" frag "${frag%%.*}"

		config_get rts "$vif" rts
		[ -n "$rts" ] && iwconfig "$ifname" rts "${rts%%.*}"

		config_get cwmin "$vif" cwmin
		[ -n "$cwmin" ] && iwpriv "$ifname" cwmin ${cwmin}

		config_get cwmax "$vif" cwmax
		[ -n "$cwmax" ] && iwpriv "$ifname" cwmax ${cwmax}

		config_get aifs "$vif" aifs
		[ -n "$aifs" ] && iwpriv "$ifname" aifs ${aifs}

		config_get txoplimit "$vif" txoplimit
		[ -n "$txoplimit" ] && iwpriv "$ifname" txoplimit ${txoplimit}

		config_get noackpolicy "$vif" noackpolicy
		[ -n "$noackpolicy" ] && iwpriv "$ifname" noackpolicy ${noackpolicy}

		config_get_bool wmm "$vif" wmm
		[ -n "$wmm" ] && iwpriv "$ifname" wmm "$wmm"

		config_get_bool doth "$vif" doth
		[ -n "$doth" ] && iwpriv "$ifname" doth "$doth"

		config_get doth_chanswitch "$vif" doth_chanswitch
		[ -n "$doth_chanswitch" ] && iwpriv "$ifname" doth_chanswitch ${doth_chanswitch}

		config_get quiet "$vif" quiet
		[ -n "$quiet" ] && iwpriv "$ifname" quiet "$quiet"

		config_get mfptest "$vif" mfptest
		[ -n "$mfptest" ] && iwpriv "$ifname" mfptest "$mfptest"

		config_get dtim_period "$vif" dtim_period
		[ -n "$dtim_period" ] && iwpriv "$ifname" dtim_period "$dtim_period"

		config_get noedgech "$vif" noedgech
		[ -n "$noedgech" ] && iwpriv "$ifname" noedgech "$noedgech"

		config_get ps_on_time "$vif" ps_on_time
		[ -n "$ps_on_time" ] && iwpriv "$ifname" ps_on_time "$ps_on_time"

		config_get inact "$vif" inact
		[ -n "$inact" ] && iwpriv "$ifname" inact "$inact"

		config_get wnm "$vif" wnm
		[ -n "$wnm" ] && iwpriv "$ifname" wnm "$wnm"

		config_get mbo "$vif" mbo
		[ -n "$mbo" ] && iwpriv "$ifname" mbo "$mbo"

		config_get enable_fils  "$vif" ieee80211ai
		config_get fils_discovery_period  "$vif" fils_fd_period 0
		[ -n "$enable_fils" ] && iwpriv "$ifname" enable_fils "$enable_fils" "$fils_discovery_period"

		config_get bpr_enable  "$vif" bpr_enable
		[ -n "$bpr_enable" ] && iwpriv "$ifname" set_bpr_enable "$bpr_enable"

		config_get oce "$vif" oce
		[ -n "$oce" ] && iwpriv "$ifname" oce "$oce"
		[ -n "$oce" ] && [ "$oce" -gt 0 ] && {
			case "$hwmode" in
				11B*|11G*|11NG*)
					iwpriv "$ifname" set_bcn_rate 5500
					iwpriv "$ifname" prb_rate 5500
					;;
				*)
					;;
			esac

			[ -z "$enable_fils" ] && iwpriv "$ifname" enable_fils 1 20
		}

		config_get ampdu "$vif" ampdu
		[ -n "$ampdu" ] && iwpriv "$ifname" ampdu "$ampdu"

		config_get amsdu "$vif" amsdu
		[ -n "$amsdu" ] && iwpriv "$ifname" amsdu "$amsdu"

		config_get maxampdu "$vif" maxampdu
		[ -n "$maxampdu" ] && iwpriv "$ifname" maxampdu "$maxampdu"

		config_get vhtmaxampdu "$vif" vhtmaxampdu
		[ -n "$vhtmaxampdu" ] && iwpriv "$ifname" vhtmaxampdu "$vhtmaxampdu"

		config_get setaddbaoper "$vif" setaddbaoper
		[ -n "$setaddbaoper" ] && iwpriv "$ifname" setaddbaoper "$setaddbaoper"

		config_get addbaresp "$vif" addbaresp
		[ -n "$addbaresp" ] && iwpriv "$ifname" $addbaresp

		config_get addba "$vif" addba
		[ -n "$addba" ] && iwpriv "$ifname" addba $addba

		config_get delba "$vif" delba
		[ -n "$delba" ] && iwpriv "$ifname" delba $delba

		config_get_bool stafwd "$vif" stafwd 0
		[ -n "$stafwd" ] && iwpriv "$ifname" stafwd "$stafwd"

		config_get maclist "$vif" maclist
		[ -n "$maclist" ] && {
			# flush MAC list
			iwpriv "$ifname" maccmd 3
			for mac in $maclist; do
				iwpriv "$ifname" addmac "$mac"
			done
		}

		config_get macfilter "$vif" macfilter
		case "$macfilter" in
			allow)
				iwpriv "$ifname" maccmd 1
			;;
			deny)
				iwpriv "$ifname" maccmd 2
			;;
			*)
				# default deny policy if mac list exists
				[ -n "$maclist" ] && iwpriv "$ifname" maccmd 2
			;;
		esac

		config_get nss "$vif" nss
		[ -n "$nss" ] && iwpriv "$ifname" nss "$nss"

		config_get vht_mcsmap "$vif" vht_mcsmap
		[ -n "$vht_mcsmap" ] && iwpriv "$ifname" vht_mcsmap "$vht_mcsmap"

		config_get chwidth "$vif" chwidth
		[ -n "$chwidth" ] && iwpriv "$ifname" chwidth "$chwidth"

		config_get chbwmode "$vif" chbwmode
		[ -n "$chbwmode" ] && iwpriv "$ifname" chbwmode "$chbwmode"

		config_get ldpc "$vif" ldpc
		[ -n "$ldpc" ] && iwpriv "$ifname" ldpc "$ldpc"

		config_get rx_stbc "$vif" rx_stbc
		[ -n "$rx_stbc" ] && iwpriv "$ifname" rx_stbc "$rx_stbc"

		config_get tx_stbc "$vif" tx_stbc
		[ -n "$tx_stbc" ] && iwpriv "$ifname" tx_stbc "$tx_stbc"

		config_get cca_thresh "$vif" cca_thresh
		[ -n "$cca_thresh" ] && iwpriv "$ifname" cca_thresh "$cca_thresh"

		config_get set11NRetries "$vif" set11NRetries
		[ -n "$set11NRetries" ] && iwpriv "$ifname" set11NRetries "$set11NRetries"

		config_get chanbw "$vif" chanbw
		[ -n "$chanbw" ] && iwpriv "$ifname" chanbw "$chanbw"

		config_get maxsta "$vif" maxsta
		[ -n "$maxsta" ] && iwpriv "$ifname" maxsta "$maxsta"

		config_get sko_max_xretries "$vif" sko_max_xretries
		[ -n "$sko_max_xretries" ] && iwpriv "$ifname" sko "$sko_max_xretries"

		config_get extprotmode "$vif" extprotmode
		[ -n "$extprotmode" ] && iwpriv "$ifname" extprotmode "$extprotmode"

		config_get extprotspac "$vif" extprotspac
		[ -n "$extprotspac" ] && iwpriv "$ifname" extprotspac "$extprotspac"

		config_get_bool cwmenable "$vif" cwmenable
		[ -n "$cwmenable" ] && iwpriv "$ifname" cwmenable "$cwmenable"

		config_get_bool protmode "$vif" protmode
		[ -n "$protmode" ] && iwpriv "$ifname" protmode "$protmode"

		config_get enablertscts "$vif" enablertscts
		[ -n "$enablertscts" ] && iwpriv "$ifname" enablertscts "$enablertscts"

		config_get txcorrection "$vif" txcorrection
		[ -n "$txcorrection" ] && iwpriv "$ifname" txcorrection "$txcorrection"

		config_get rxcorrection "$vif" rxcorrection
		[ -n "$rxcorrection" ] && iwpriv "$ifname" rxcorrection "$rxcorrection"

                config_get vsp_enable "$vif" vsp_enable
                [ -n "$vsp_enable" ] && iwpriv "$ifname" vsp_enable "$vsp_enable"

		config_get ssid "$vif" ssid
		[ -n "$ssid" ] && iwconfig "$ifname" essid ${ssid:+-- }"$ssid"

		config_get txqueuelen "$vif" txqueuelen
		[ -n "$txqueuelen" ] && ifconfig "$ifname" txqueuelen "$txqueuelen"

                net_cfg="$(find_net_config "$vif")"

                config_get mtu $net_cfg mtu

                [ -n "$mtu" ] && {
                        config_set "$vif" mtu $mtu
                        ifconfig "$ifname" mtu $mtu
		}

		config_get tdls "$vif" tdls
		[ -n "$tdls" ] && iwpriv "$ifname" tdls "$tdls"

		config_get set_tdls_rmac "$vif" set_tdls_rmac
		[ -n "$set_tdls_rmac" ] && iwpriv "$ifname" set_tdls_rmac "$set_tdls_rmac"

		config_get tdls_qosnull "$vif" tdls_qosnull
		[ -n "$tdls_qosnull" ] && iwpriv "$ifname" tdls_qosnull "$tdls_qosnull"

		config_get tdls_uapsd "$vif" tdls_uapsd
		[ -n "$tdls_uapsd" ] && iwpriv "$ifname" tdls_uapsd "$tdls_uapsd"

		config_get tdls_set_rcpi "$vif" tdls_set_rcpi
		[ -n "$tdls_set_rcpi" ] && iwpriv "$ifname" set_rcpi "$tdls_set_rcpi"

		config_get tdls_set_rcpi_hi "$vif" tdls_set_rcpi_hi
		[ -n "$tdls_set_rcpi_hi" ] && iwpriv "$ifname" set_rcpihi "$tdls_set_rcpi_hi"

		config_get tdls_set_rcpi_lo "$vif" tdls_set_rcpi_lo
		[ -n "$tdls_set_rcpi_lo" ] && iwpriv "$ifname" set_rcpilo "$tdls_set_rcpi_lo"

		config_get tdls_set_rcpi_margin "$vif" tdls_set_rcpi_margin
		[ -n "$tdls_set_rcpi_margin" ] && iwpriv "$ifname" set_rcpimargin "$tdls_set_rcpi_margin"

		config_get tdls_dtoken "$vif" tdls_dtoken
		[ -n "$tdls_dtoken" ] && iwpriv "$ifname" tdls_dtoken "$tdls_dtoken"

		config_get do_tdls_dc_req "$vif" do_tdls_dc_req
		[ -n "$do_tdls_dc_req" ] && iwpriv "$ifname" do_tdls_dc_req "$do_tdls_dc_req"

		config_get tdls_auto "$vif" tdls_auto
		[ -n "$tdls_auto" ] && iwpriv "$ifname" tdls_auto "$tdls_auto"

		config_get tdls_off_timeout "$vif" tdls_off_timeout
		[ -n "$tdls_off_timeout" ] && iwpriv "$ifname" off_timeout "$tdls_off_timeout"

		config_get tdls_tdb_timeout "$vif" tdls_tdb_timeout
		[ -n "$tdls_tdb_timeout" ] && iwpriv "$ifname" tdb_timeout "$tdls_tdb_timeout"

		config_get tdls_weak_timeout "$vif" tdls_weak_timeout
		[ -n "$tdls_weak_timeout" ] && iwpriv "$ifname" weak_timeout "$tdls_weak_timeout"

		config_get tdls_margin "$vif" tdls_margin
		[ -n "$tdls_margin" ] && iwpriv "$ifname" tdls_margin "$tdls_margin"

		config_get tdls_rssi_ub "$vif" tdls_rssi_ub
		[ -n "$tdls_rssi_ub" ] && iwpriv "$ifname" tdls_rssi_ub "$tdls_rssi_ub"

		config_get tdls_rssi_lb "$vif" tdls_rssi_lb
		[ -n "$tdls_rssi_lb" ] && iwpriv "$ifname" tdls_rssi_lb "$tdls_rssi_lb"

		config_get tdls_path_sel "$vif" tdls_path_sel
		[ -n "$tdls_path_sel" ] && iwpriv "$ifname" tdls_pathSel "$tdls_path_sel"

		config_get tdls_rssi_offset "$vif" tdls_rssi_offset
		[ -n "$tdls_rssi_offset" ] && iwpriv "$ifname" tdls_rssi_o "$tdls_rssi_offset"

		config_get tdls_path_sel_period "$vif" tdls_path_sel_period
		[ -n "$tdls_path_sel_period" ] && iwpriv "$ifname" tdls_pathSel_p "$tdls_path_sel_period"

		config_get tdlsmacaddr1 "$vif" tdlsmacaddr1
		[ -n "$tdlsmacaddr1" ] && iwpriv "$ifname" tdlsmacaddr1 "$tdlsmacaddr1"

		config_get tdlsmacaddr2 "$vif" tdlsmacaddr2
		[ -n "$tdlsmacaddr2" ] && iwpriv "$ifname" tdlsmacaddr2 "$tdlsmacaddr2"

		config_get tdlsaction "$vif" tdlsaction
		[ -n "$tdlsaction" ] && iwpriv "$ifname" tdlsaction "$tdlsaction"

		config_get tdlsoffchan "$vif" tdlsoffchan
		[ -n "$tdlsoffchan" ] && iwpriv "$ifname" tdlsoffchan "$tdlsoffchan"

		config_get tdlsswitchtime "$vif" tdlsswitchtime
		[ -n "$tdlsswitchtime" ] && iwpriv "$ifname" tdlsswitchtime "$tdlsswitchtime"

		config_get tdlstimeout "$vif" tdlstimeout
		[ -n "$tdlstimeout" ] && iwpriv "$ifname" tdlstimeout "$tdlstimeout"

		config_get tdlsecchnoffst "$vif" tdlsecchnoffst
		[ -n "$tdlsecchnoffst" ] && iwpriv "$ifname" tdlsecchnoffst "$tdlsecchnoffst"

		config_get tdlsoffchnmode "$vif" tdlsoffchnmode
		[ -n "$tdlsoffchnmode" ] && iwpriv "$ifname" tdlsoffchnmode "$tdlsoffchnmode"

		config_get_bool blockdfschan "$vif" blockdfschan
		[ -n "$blockdfschan" ] && iwpriv "$ifname" blockdfschan "$blockdfschan"

		config_get dbgLVL "$vif" dbgLVL
		[ -n "$dbgLVL" ] && iwpriv "$ifname" dbgLVL "$dbgLVL"

		config_get acsmindwell "$vif" acsmindwell
		[ -n "$acsmindwell" ] && iwpriv "$ifname" acsmindwell "$acsmindwell"

		config_get acsmaxdwell "$vif" acsmaxdwell
		[ -n "$acsmaxdwell" ] && iwpriv "$ifname" acsmaxdwell "$acsmaxdwell"

		config_get acsreport "$vif" acsreport
		[ -n "$acsreport" ] && iwpriv "$ifname" acsreport "$acsreport"

		config_get ch_hop_en "$vif" ch_hop_en
		[ -n "$ch_hop_en" ] && iwpriv "$ifname" ch_hop_en "$ch_hop_en"

		config_get ch_long_dur "$vif" ch_long_dur
		[ -n "$ch_long_dur" ] && iwpriv "$ifname" ch_long_dur "$ch_long_dur"

		config_get ch_nhop_dur "$vif" ch_nhop_dur
		[ -n "$ch_nhop_dur" ] && iwpriv "$ifname" ch_nhop_dur "$ch_nhop_dur"

		config_get ch_cntwn_dur "$vif" ch_cntwn_dur
		[ -n "$ch_cntwn_dur" ] && iwpriv "$ifname" ch_cntwn_dur "$ch_cntwn_dur"

		config_get ch_noise_th "$vif" ch_noise_th
		[ -n "$ch_noise_th" ] && iwpriv "$ifname" ch_noise_th "$ch_noise_th"

		config_get ch_cnt_th "$vif" ch_cnt_th
		[ -n "$ch_cnt_th" ] && iwpriv "$ifname" ch_cnt_th "$ch_cnt_th"

		config_get_bool scanchevent "$vif" scanchevent
		[ -n "$scanchevent" ] && iwpriv "$ifname" scanchevent "$scanchevent"

		config_get_bool send_add_ies "$vif" send_add_ies
		[ -n "$send_add_ies" ] && iwpriv "$ifname" send_add_ies "$send_add_ies"

		config_get_bool ext_ifu_acs "$vif" ext_ifu_acs
		[ -n "$ext_ifu_acs" ] && iwpriv "$ifname" ext_ifu_acs "$ext_ifu_acs"

		config_get_bool enable_rtt "$vif" enable_rtt
		[ -n "$enable_rtt" ] && iwpriv "$ifname" enable_rtt "$enable_rtt"

		config_get_bool enable_lci "$vif" enable_lci
		[ -n "$enable_lci" ] && iwpriv "$ifname" enable_lci "$enable_lci"

		config_get_bool enable_lcr "$vif" enable_lcr
		[ -n "$enable_lcr" ] && iwpriv "$ifname" enable_lcr "$enable_lcr"

		config_get_bool rrm "$vif" rrm
		[ -n "$rrm" ] && iwpriv "$ifname" rrm "$rrm"

		config_get_bool rrmslwin "$vif" rrmslwin
		[ -n "$rrmslwin" ] && iwpriv "$ifname" rrmslwin "$rrmslwin"

		config_get_bool rrmstats "$vif" rrmsstats
		[ -n "$rrmstats" ] && iwpriv "$ifname" rrmstats "$rrmstats"

		config_get rrmdbg "$vif" rrmdbg
		[ -n "$rrmdbg" ] && iwpriv "$ifname" rrmdbg "$rrmdbg"

		config_get acparams "$vif" acparams
		[ -n "$acparams" ] && iwpriv "$ifname" acparams $acparams

		config_get setwmmparams "$vif" setwmmparams
		[ -n "$setwmmparams" ] && iwpriv "$ifname" setwmmparams $setwmmparams

		config_get_bool qbssload "$vif" qbssload
		[ -n "$qbssload" ] && iwpriv "$ifname" qbssload "$qbssload"

		config_get_bool proxyarp "$vif" proxyarp
		[ -n "$proxyarp" ] && iwpriv "$ifname" proxyarp "$proxyarp"

		config_get_bool dgaf_disable "$vif" dgaf_disable
		[ -n "$dgaf_disable" ] && iwpriv "$ifname" dgaf_disable "$dgaf_disable"

		config_get setibssdfsparam "$vif" setibssdfsparam
		[ -n "$setibssdfsparam" ] && iwpriv "$ifname" setibssdfsparam "$setibssdfsparam"

		config_get startibssrssimon "$vif" startibssrssimon
		[ -n "$startibssrssimon" ] && iwpriv "$ifname" startibssrssimon "$startibssrssimon"

		config_get setibssrssihyst "$vif" setibssrssihyst
		[ -n "$setibssrssihyst" ] && iwpriv "$ifname" setibssrssihyst "$setibssrssihyst"

		config_get noIBSSCreate "$vif" noIBSSCreate
		[ -n "$noIBSSCreate" ] && iwpriv "$ifname" noIBSSCreate "$noIBSSCreate"

		config_get setibssrssiclass "$vif" setibssrssiclass
		[ -n "$setibssrssiclass" ] && iwpriv "$ifname" setibssrssiclass $setibssrssiclass

		config_get offchan_tx_test "$vif" offchan_tx_test
		[ -n "$offchan_tx_test" ] && iwpriv "$ifname" offchan_tx_test $offchan_tx_test

		handle_vow_dbg_cfg() {
			local value="$1"
			[ -n "$value" ] && iwpriv "$ifname" vow_dbg_cfg $value
		}

		config_list_foreach "$vif" vow_dbg_cfg handle_vow_dbg_cfg

		config_get_bool vow_dbg "$vif" vow_dbg
		[ -n "$vow_dbg" ] && iwpriv "$ifname" vow_dbg "$vow_dbg"

		handle_set_max_rate() {
			local value="$1"
			[ -n "$value" ] && wlanconfig "$ifname" set_max_rate $value
		}
		config_list_foreach "$vif" set_max_rate handle_set_max_rate

		config_get_bool implicitbf "$vif" implicitbf
		[ -n "$implicitbf" ] && iwpriv "$ifname" implicitbf "${implicitbf}"

		config_get_bool vhtsubfee "$vif" vhtsubfee
		[ -n "$vhtsubfee" ] && iwpriv "$ifname" vhtsubfee "${vhtsubfee}"

		config_get_bool vhtmubfee "$vif" vhtmubfee
		[ -n "$vhtmubfee" ] && iwpriv "$ifname" vhtmubfee "${vhtmubfee}"

		config_get_bool vhtsubfer "$vif" vhtsubfer
		[ -n "$vhtsubfer" ] && iwpriv "$ifname" vhtsubfer "${vhtsubfer}"

		config_get_bool vhtmubfer "$vif" vhtmubfer
		[ -n "$vhtmubfer" ] && iwpriv "$ifname" vhtmubfer "${vhtmubfer}"

		config_get vhtstscap "$vif" vhtstscap
		[ -n "$vhtstscap" ] && iwpriv "$ifname" vhtstscap "${vhtstscap}"

		config_get vhtsounddim "$vif" vhtsounddim
		[ -n "$vhtsounddim" ] && iwpriv "$ifname" vhtsounddim "${vhtsounddim}"

		config_get encap_type "$vif" encap_type
		[ -n "$encap_type" ] && iwpriv "$ifname" encap_type "${encap_type}"

		config_get decap_type "$vif" decap_type
		[ -n "$decap_type" ] && iwpriv "$ifname" decap_type "${decap_type}"

		config_get_bool rawsim_txagr "$vif" rawsim_txagr
		[ -n "$rawsim_txagr" ] && iwpriv "$ifname" rawsim_txagr "${rawsim_txagr}"

		config_get clr_rawsim_stats "$vif" clr_rawsim_stats
		[ -n "$clr_rawsim_stats" ] && iwpriv "$ifname" clr_rawsim_stats "${clr_rawsim_stats}"

		config_get_bool rawsim_debug "$vif" rawsim_debug
		[ -n "$rawsim_debug" ] && iwpriv "$ifname" rawsim_debug "${rawsim_debug}"

		config_get set_monrxfilter "$vif" set_monrxfilter
		[ -n "$set_monrxfilter" ] && iwpriv "$ifname" set_monrxfilter "${set_monrxfilter}"

		config_get neighbourfilter "$vif" neighbourfilter
		[ -n "$neighbourfilter" ] && iwpriv "$ifname" neighbourfilter "${neighbourfilter}"

		config_get athnewind "$vif" athnewind
		[ -n "$athnewind" ] && iwpriv "$ifname" athnewind "$athnewind"

		config_get osen "$vif" osen
		[ -n "$osen" ] && iwpriv "$ifname" osen "$osen"

		config_get re_scalingfactor "$vif" re_scalingfactor
		[ -n "$re_scalingfactor" ] && iwpriv "$ifname" set_whc_sfactor "$re_scalingfactor"

		config_get root_distance "$vif" root_distance
		[ -n "$root_distance" ] && iwpriv "$ifname" set_whc_dist "$root_distance"

		config_get caprssi "$vif" caprssi
		[ -n "$caprssi" ] && iwpriv "$ifname" caprssi "${caprssi}"

		config_get_bool ap_isolation_enabled $device ap_isolation_enabled 0
		config_get_bool isolate "$vif" isolate 0

		if [ $ap_isolation_enabled -ne 0 ]; then
			[ "$mode" = "wrap" ] && isolate=1
		fi

		config_get_bool ctsprt_dtmbcn "$vif" ctsprt_dtmbcn
		[ -n "$ctsprt_dtmbcn" ] && iwpriv "$ifname" ctsprt_dtmbcn "${ctsprt_dtmbcn}"

		config_get assocwar160  "$vif" assocwar160
		[ -n "$assocwar160" ] && iwpriv "$ifname" assocwar160 "$assocwar160"

		config_get rawdwepind "$vif" rawdwepind
		[ -n "$rawdwepind" ] && iwpriv "$ifname" rawdwepind "$rawdwepind"

		config_get revsig160  "$vif" revsig160
		[ -n "$revsig160" ] && iwpriv "$ifname" revsig160 "$revsig160"

		config_get channel_block_list "$vif" channel_block_list
		[ -n "$channel_block_list" ] && wifitool "$ifname" block_acs_channel "$channel_block_list"

		config_get rept_spl  "$vif" rept_spl
		[ -n "$rept_spl" ] && iwpriv "$ifname" rept_spl "$rept_spl"

		config_get cactimeout  "$vif" cactimeout 5
		[ -n "$cactimeout" ] && iwpriv "$ifname" set_cactimeout "$cactimeout"

		config_get pref_uplink "$device" pref_uplink
		[ -n "$pref_uplink" ] && iwpriv "$phy" pref_uplink "${pref_uplink}"

		config_get fast_lane "$device" fast_lane
		[ -n "$fast_lane" ] && iwpriv "$phy" fast_lane "${fast_lane}"

		[ -n "$fast_lane" ] && [ $fast_lane -ne 0 ] && iwpriv "$ifname" athnewind 1


		local net_cfg bridge
		net_cfg="$(find_net_config "$vif")"
		[ -z "$net_cfg" -o "$isolate" = 1 -a "$mode" = "wrap" ] || {
                        [ -f /sys/class/net/${ifname}/parent ] && { \
				bridge="$(bridge_interface "$net_cfg")"
				config_set "$vif" bridge "$bridge"
                        }
		}

		case "$mode" in
			ap|wrap|ap_monitor|ap_smart_monitor|mesh|ap_lp_iot)


				iwpriv "$ifname" ap_bridge "$((isolate^1))"

				config_get_bool l2tif "$vif" l2tif
				[ -n "$l2tif" ] && iwpriv "$ifname" l2tif "$l2tif"

				if [ -n "$start_wapid" ]; then
					wapid_setup_vif "$vif" || {
						echo "enable_qcawifi($device): Failed to set up wapid for interface $ifname" >&2
						ifconfig "$ifname" down
						wlanconfig "$ifname" destroy
						continue
					}
				fi

				if [ -n "$start_hostapd" ] && eval "type hostapd_setup_vif" 2>/dev/null >/dev/null; then
					hostapd_setup_vif "$vif" atheros no_nconfig || {
						echo "enable_qcawifi($device): Failed to set up hostapd for interface $ifname" >&2
						# make sure this wifi interface won't accidentally stay open without encryption
						ifconfig "$ifname" down
						wlanconfig "$ifname" destroy
						continue
					}
					ifconfig "$ifname" down # hostapd_setup_vif, for some reason, raise the interface up
				fi
			;;
			wds|sta)
				if eval "type wpa_supplicant_setup_vif" 2>/dev/null >/dev/null; then
					wpa_supplicant_setup_vif "$vif" athr || {
						echo "enable_qcawifi($device): Failed to set up wpa_supplicant for interface $ifname" >&2
						ifconfig "$ifname" down
						wlanconfig "$ifname" destroy
						continue
					}
				fi
			;;
			adhoc)
				if eval "type wpa_supplicant_setup_vif" 2>/dev/null >/dev/null; then
					wpa_supplicant_setup_vif "$vif" athr || {
						echo "enable_qcawifi($device): Failed to set up wpa"
						ifconfig "$ifname" down
						wlanconfig "$ifname" destroy
						continue
					}
				fi
		esac

		[ -z "$bridge" -o "$isolate" = 1 -a "$mode" = "wrap" ] || {
                        [ -f /sys/class/net/${ifname}/parent ] && { \
				start_net "$ifname" "$net_cfg"
                        }
		}

		ifconfig "$ifname" up
		[ "$ifname" = "ath0" ] && sleep 5
		set_wifi_up "$vif" "$ifname"

		# No idea why, but this is necessary in order to WDS/extAP work
		ifconfig "$ifname" down
		ifconfig "$ifname" up

		config_get set11NRates "$vif" set11NRates
		[ -n "$set11NRates" ] && iwpriv "$ifname" set11NRates "$set11NRates"

		# 256 QAM capability needs to be parsed first, since
		# vhtmcs enables/disable rate indices 8, 9 for 2G
		# only if vht_11ng is set or not
		config_get_bool vht_11ng "$vif" vht_11ng
		[ -n "$vht_11ng" ] && iwpriv "$ifname" vht_11ng "$vht_11ng"

		config_get vhtmcs "$vif" vhtmcs
		[ -n "$vhtmcs" ] && iwpriv "$ifname" vhtmcs "$vhtmcs"

		config_get dis_legacy "$vif" dis_legacy
		[ -n "$dis_legacy" ] && iwpriv "$ifname" dis_legacy "$dis_legacy"

		config_get set_bcn_rate "$vif" set_bcn_rate
		[ -n "$set_bcn_rate" ] && iwpriv "$ifname" set_bcn_rate "$set_bcn_rate"

		handle_hmmc_add() {
			local value="$1"
			[ -n "$value" ] && wlanconfig "$ifname" hmmc add $value
		}
		config_list_foreach "$vif" hmmc_add handle_hmmc_add

		# TXPower settings only work if device is up already
		# while atheros hardware theoretically is capable of per-vif (even per-packet) txpower
		# adjustment it does not work with the current atheros hal/madwifi driver

		config_get vif_txpower "$vif" txpower
		# use vif_txpower (from wifi-iface) instead of txpower (from wifi-device) if
		# the latter doesn't exist
		txpower="${txpower:-$vif_txpower}"
		[ -z "$txpower" ] || iwconfig "$ifname" txpower "${txpower%%.*}"

		if [ $enable_rps_wifi == 1 ] && [ -f "/lib/update_system_params.sh" ]; then
			. /lib/update_system_params.sh
			enable_rps $ifname
		fi

		config_get macaddr "$device" macaddr
		[ -n "$macaddr" ] && iwpriv "$phy" setHwaddr "$macaddr"


	done

	config_get primaryradio "$device" primaryradio
	[ -n "$primaryradio" ] && iwpriv "$phy" primaryradio "${primaryradio}"

	config_get CSwOpts "$device" CSwOpts
	[ -n "$CSwOpts" ] && iwpriv "$phy" CSwOpts "${CSwOpts}"

	if [ $disable_qrfs_wifi == 1 ] && [ -f "/lib/update_system_params.sh" ]; then
		. /lib/update_system_params.sh
		disable_qrfs
	fi

	if [ -f "/lib/update_smp_affinity.sh" ]; then
		config_load wireless
		. /lib/update_smp_affinity.sh
		config_foreach enable_smp_affinity_wifi wifi-device
	fi

	lock -u /var/run/wifilock
}

setup_wps_enhc_device() {
	local device=$1
	local wps_enhc_cfg=

	append wps_enhc_cfg "RADIO" "$N"
	config_get_bool wps_pbc_try_sta_always "$device" wps_pbc_try_sta_always 0
	config_get_bool wps_pbc_skip_ap_if_sta_disconnected "$device" wps_pbc_skip_ap_if_sta_disconnected 0
	config_get_bool wps_pbc_overwrite_ap_settings "$device" wps_pbc_overwrite_ap_settings 0
	config_get wps_pbc_overwrite_ssid_band_suffix "$device" wps_pbc_overwrite_ssid_band_suffix
	[ $wps_pbc_try_sta_always -ne 0 ] && \
			append wps_enhc_cfg "$device:try_sta_always" "$N"
	[ $wps_pbc_skip_ap_if_sta_disconnected -ne 0 ] && \
			append wps_enhc_cfg "$device:skip_ap_if_sta_disconnected" "$N"
	[ $wps_pbc_overwrite_ap_settings -ne 0 ] && \
			append wps_enhc_cfg "$device:overwrite_ap_settings" "$N"
	[ -n "$wps_pbc_overwrite_ssid_band_suffix" ] && \
			append wps_enhc_cfg "$device:overwrite_ssid_band_suffix:$wps_pbc_overwrite_ssid_band_suffix" "$N"

	config_get vifs $device vifs

	for vif in $vifs; do
		config_get ifname "$vif" ifname

		config_get_bool wps_pbc_enable "$vif" wps_pbc_enable 0
		config_get wps_pbc_start_time "$vif" wps_pbc_start_time
		config_get wps_pbc_duration "$vif" wps_pbc_duration
		config_get_bool wps_pbc_noclone "$vif" wps_pbc_noclone 0
		config_get_bool disabled "$vif" disabled 0
		if [ $disabled -eq 0 -a $wps_pbc_enable -ne 0 ]; then
			append wps_enhc_cfg "VAP" "$N"
			[ -n "$wps_pbc_start_time" -a -n "$wps_pbc_duration" ] && {
				if [ $wps_pbc_noclone -eq 0 ]; then
					append wps_enhc_cfg "$ifname:$wps_pbc_start_time:$wps_pbc_duration:$device:clone" "$N"
				else
					append wps_enhc_cfg "$ifname:$wps_pbc_start_time:$wps_pbc_duration:$device:noclone" "$N"
				fi
			}
			[ -n "$wps_pbc_start_time" -a -n "$wps_pbc_duration" ] || {
				if [ $wps_pbc_noclone -eq 0 ]; then
					append wps_enhc_cfg "$ifname:-:-:$device:clone" "$N"
				else
					append wps_enhc_cfg "$ifname:-:-:$device:noclone" "$N"
				fi
			}
		fi
	done

	cat >> /var/run/wifi-wps-enhc-extn.conf <<EOF
$wps_enhc_cfg
EOF
}

setup_wps_enhc() {
	local wps_enhc_cfg=

	append wps_enhc_cfg "GLOBAL" "$N"
	config_get_bool wps_pbc_overwrite_ap_settings_all qcawifi wps_pbc_overwrite_ap_settings_all 0
	[ $wps_pbc_overwrite_ap_settings_all -ne 0 ] && \
			append wps_enhc_cfg "-:overwrite_ap_settings_all" "$N"
	config_get_bool wps_pbc_overwrite_sta_settings_all qcawifi wps_pbc_overwrite_sta_settings_all 0
	[ $wps_pbc_overwrite_sta_settings_all -ne 0 ] && \
			append wps_enhc_cfg "-:overwrite_sta_settings_all" "$N"
	config_get wps_pbc_overwrite_ssid_suffix qcawifi wps_pbc_overwrite_ssid_suffix
	[ -n "$wps_pbc_overwrite_ssid_suffix" ] && \
			append wps_enhc_cfg "-:overwrite_ssid_suffix:$wps_pbc_overwrite_ssid_suffix" "$N"

	cat >> /var/run/wifi-wps-enhc-extn.conf <<EOF
$wps_enhc_cfg
EOF

	config_load wireless
	config_foreach setup_wps_enhc_device wifi-device
}

qcawifi_start_hostapd_cli() {
	local device=$1
	local ifidx=0
	local radioidx=${device#radio}

	config_get vifs $device vifs

	for vif in $vifs; do
		local config_methods vifname

		config_get vifname "$vif" ifname

		if [ -n $vifname ]; then
			[ $ifidx -gt 0 ] && vifname="ath${radioidx}$ifidx" || vifname="ath${radioidx}"
		fi

		config_get_bool wps_pbc "$vif" wps_pbc 0
		config_get config_methods "$vif" wps_config
		[ "$wps_pbc" -gt 0 ] && append config_methods push_button

		if [ -n "$config_methods" ]; then
			pid=/var/run/hostapd_cli-$vifname.pid
			hostapd_cli -i $vifname -P $pid -a /lib/wifi/wps-hostapd-update-uci -p /var/run/hostapd-$device -B
		fi

		ifidx=$(($ifidx + 1))
	done
}

pre_qcawifi() {
	local action=${1}

	config_load wireless

	lock /var/run/wifilock
	case "${action}" in
		disable)
			config_get_bool wps_vap_tie_dbdc qcawifi wps_vap_tie_dbdc 0

			if [ $wps_vap_tie_dbdc -ne 0 ]; then
				kill "$(cat "/var/run/hostapd.pid")"
				[ -f "/tmp/hostapd_conf_filename" ] &&
					rm /tmp/hostapd_conf_filename
			fi

			eval "type qwrap_teardown" >/dev/null 2>&1 && qwrap_teardown
			eval "type icm_teardown" >/dev/null 2>&1 && icm_teardown
			eval "type wpc_teardown" >/dev/null 2>&1 && wpc_teardown
			eval "type lowi_teardown" >/dev/null 2>&1 && lowi_teardown
			[ ! -f /etc/init.d/lbd ] || /etc/init.d/lbd stop
			[ ! -f /etc/init.d/hyd ] || /etc/init.d/hyd stop
			[ ! -f /etc/init.d/ssid_steering ] || /etc/init.d/ssid_steering stop
			[ ! -f /etc/init.d/mcsd ] || /etc/init.d/mcsd stop
			[ ! -f /etc/init.d/wsplcd ] || /etc/init.d/wsplcd stop

                       rm -f /var/run/wifi-wps-enhc-extn.conf
                       [ -r /var/run/wifi-wps-enhc-extn.pid ] && kill "$(cat "/var/run/wifi-wps-enhc-extn.pid")"

			rm -f /var/run/iface_mgr.conf
			[ -r /var/run/iface_mgr.pid ] && kill "$(cat "/var/run/iface_mgr.pid")"
                        rm -f /var/run/iface_mgr.pid
			killall iface-mgr
			
		;;
	esac
	lock -u /var/run/wifilock
}

post_qcawifi() {
	local action=${1}

	lock /var/run/wifilock
	case "${action}" in
		enable)
			local icm_enable qwrap_enable lowi_enable

			# Run a single hostapd instance for all the radio's
			# Enables WPS VAP TIE feature

			config_get_bool wps_vap_tie_dbdc qcawifi wps_vap_tie_dbdc 0

			if [ $wps_vap_tie_dbdc -ne 0 ]; then
				hostapd_conf_file=$(cat "/tmp/hostapd_conf_filename")
				hostapd -P /var/run/hostapd.pid $hostapd_conf_file -B
				config_foreach qcawifi_start_hostapd_cli wifi-device
			fi

			config_get_bool icm_enable icm enable 0
			[ ${icm_enable} -gt 0 ] && \
					eval "type icm_setup" >/dev/null 2>&1 && {
				icm_setup
			}

			config_get_bool wpc_enable wpc enable 0
			[ ${wpc_enable} -gt 0 ] && \
					eval "type wpc_setup" >/dev/null 2>&1 && {
				wpc_setup
			}

			config_get_bool lowi_enable lowi enable 0
			[ ${lowi_enable} -gt 0 ] && \
				eval "type lowi_setup" >/dev/null 2>&1 && {
				lowi_setup
			}

			eval "type qwrap_setup" >/dev/null 2>&1 && qwrap_setup && _disable_qcawifi

			# These init scripts are assumed to check whether the feature is
			# actually enabled and do nothing if it is not.
			[ ! -f /etc/init.d/lbd ] || /etc/init.d/lbd start
			[ ! -f /etc/init.d/ssid_steering ] || /etc/init.d/ssid_steering start
			[ ! -f /etc/init.d/wsplcd ] || /etc/init.d/wsplcd restart

			config_get_bool wps_pbc_extender_enhance qcawifi wps_pbc_extender_enhance 0
			[ ${wps_pbc_extender_enhance} -ne 0 ] && {
				rm -f /var/run/wifi-wps-enhc-extn.conf
				setup_wps_enhc
			}

			config_load wireless

			rm -f /etc/ath/iface_mgr.conf
			rm -f /var/run/iface_mgr.pid
			iface_mgr_setup

		;;
	esac
	lock -u /var/run/wifilock
}

check_qcawifi_device() {
	[ ${1%[0-9]} = "radio" ] && config_set "$1" phy "$1"
	config_get phy "$1" phy
	[ -z "$phy" ] && {
		find_qcawifi_phy "$1" >/dev/null || return 1
		config_get phy "$1" phy
	}
	[ "$phy" = "$dev" ] && found=1
}


detect_qcawifi() {
	devidx=0
	sleep 3
	config_load wireless
	while :; do
		config_get type "radio$devidx" type
		[ -n "$type" ] || break
		devidx=$(($devidx + 1))
	done
	cd /sys/class/net
	
	for dev in $(ls -d radio* 2>&-); do
		found=0
		config_foreach check_qcawifi_device wifi-device
		[ "$found" -gt 0 ] && continue

		hwcaps=$(cat ${dev}/hwcaps)
		case "${hwcaps}" in
			*11bgn) mode_11=ng;;
			*11abgn) mode_11=ng;;
			*11an) mode_11=na;;
			*11an/ac) mode_11=ac;;
			*11abgn/ac) mode_11=ac;;
		esac
		
		config_get type radio${devidx} type;
		[ "$type" == "qcawifi" ] || {
			
			eth_mac=$(cat /sys/class/net/eth0/address)
			eth_mac=$(echo $eth_mac | tr -d ':')
			wifi_mac=$((0x$eth_mac + 2 + $devidx))
			wifi_mac=$(printf "%012x" $wifi_mac)
			wifi_mac=$(echo $wifi_mac | sed 's/../&:/g;s/:$//')

			uci -q batch <<-EOF
			set wireless.radio${devidx}=wifi-device
			set wireless.radio${devidx}.type=qcawifi
			set wireless.radio${devidx}.phy=radio${devidx}
			set wireless.radio${devidx}.macaddr=${wifi_mac}
			set wireless.radio${devidx}.hwmode=11${mode_11}
			set wireless.radio${devidx}.channel=auto
			set wireless.radio${devidx}.country=BR

			set wireless.default_radio${devidx}=wifi-iface
			set wireless.default_radio${devidx}.device=radio${devidx}
			set wireless.default_radio${devidx}.network=lan
			set wireless.default_radio${devidx}.mode=ap
			set wireless.default_radio${devidx}.ieee80211r=0
			set wireless.default_radio${devidx}.bss_transition=1
			set wireless.default_radio${devidx}.ssid=OpenWrt${devidx}
			set wireless.default_radio${devidx}.encryption=none
			EOF
			uci -q commit wireless
		}
		devidx=$(($devidx + 1))
	
	done
}

# Handle traps here
trap_qcawifi() {
	# Release any locks taken
	lock -u /var/run/wifilock
}
