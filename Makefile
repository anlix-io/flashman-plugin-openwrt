#
# Copyright (C) 2017-2017 LAND/COPPE/UFRJ
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=flasman-plugin
PKG_VERSION:=0.37.0
PKG_RELEASE:=1

PKG_LICENSE:=GPL
PKG_LICENSE_FILES:=COPYING

PKG_BUILD_PARALLEL:=1
PKG_BUILD_DIR := $(BUILD_DIR)/$(PKG_NAME)

PKG_CONFIG_DEPENDS:= \
	CONFIG_FLASHMAN_WIFI_SSID \
	CONFIG_FLASHMAN_WIFI_PASSWD \
	CONFIG_FLASHMAN_WIFI_CHANNEL \
	CONFIG_FLASHMAN_WIFI_BAND \
	CONFIG_FLASHMAN_WIFI_5GHZ_CHANNEL \
	CONFIG_FLASHMAN_WIFI_DISASSOC_LOW_ACK \
	CONFIG_FLASHMAN_RELEASE_ID \
	CONFIG_FLASHMAN_CLIENT_ORG \
	CONFIG_CONNECTIVITY_SVADDRS_LIST

include $(INCLUDE_DIR)/package.mk

define Package/flashman-plugin/Default
	SECTION:=utils
	CATEGORY:=Utilities
	PKGARCH:=all
	MAINTAINER:=Guilherme da Silva Senges <guilherme@anlix.io>
endef

define Package/flashman-plugin/description
	Dependencies and scripts for communicating with Flashman server
endef

define Package/flashman-plugin
	$(call Package/flashman-plugin/Default)
	SECTION:=utils
	CATEGORY:=Utilities
	TITLE:=Install flashman-plugin
	DEPENDS:=+curl \
			+iputils-ping \
			+iputils-ping6 \
			+uhttpd \
			+uhttpd-mod-lua \
			+px5g-mbedtls \
			+libustream-mbedtls \
			+libuuid \
			+rpcd \
			+libuci-lua \
			+libubus-lua \
			+libmbedtls \
			+iptables-mod-conntrack-extra \
			+anlix-miniupnpd \
			+anlix-minisapo \
			+flash-measure
	MENU:=1
endef

define Package/flashman-plugin/config
	source "$(SOURCE)/Config.in"
endef

define Build/Compile
  $(MAKE) -C $(PKG_BUILD_DIR) \
          CC="$(TARGET_CC)" \
          CFLAGS="$(TARGET_CFLAGS) -Wall" \
          LDFLAGS="$(TARGET_LDFLAGS)"
endef

FILE_DIR=
	ifeq ($(CONFIG_USE_DEFAULT_FLAG), y)
		FILE_DIR="files"
	endif

CUSTOM_FILE_ARQ=
	ifeq ($(CONFIG_TARGET_ramips_mt7620_DEVICE_tplink_c2-v1), y)
		CUSTOM_FILE_ARQ="tplink_archer-c2-v1"
	else ifeq ($(CONFIG_TARGET_ramips_mt7620_DEVICE_tplink_c20-v1), y)
		CUSTOM_FILE_ARQ="tplink_archer-c20-v1"
	else ifeq ($(CONFIG_TARGET_ramips_mt76x8_DEVICE_tplink_c20-v4), y)
		CUSTOM_FILE_ARQ="tplink_archer-c20-v4"
	else ifeq ($(CONFIG_TARGET_ramips_mt76x8_DEVICE_tplink_c20-v5), y)
		CUSTOM_FILE_ARQ="tplink_archer-c20-v5"
	else ifeq ($(CONFIG_TARGET_ramips_mt76x8_DEVICE_tplink_c20-v5w), y)
		CUSTOM_FILE_ARQ="tplink_archer-c20-v5W"
	else ifeq ($(CONFIG_TARGET_ramips_mt7620_DEVICE_tplink_c5-v4), y)
		CUSTOM_FILE_ARQ="tplink_archer-c5-v4"
	else ifeq ($(CONFIG_TARGET_ramips_mt76x8_DEVICE_tplink_c50-v3), y)
		CUSTOM_FILE_ARQ="tplink_archer-c50-v3"
	else ifeq ($(CONFIG_TARGET_ramips_mt76x8_DEVICE_tplink_c50-v4), y)
		CUSTOM_FILE_ARQ="tplink_archer-c50-v4"
	else ifeq ($(CONFIG_TARGET_ramips_mt7620_DEVICE_zyxel_emg1702-t10a-a1), y)
		CUSTOM_FILE_ARQ="tbs"
	else ifeq ($(CONFIG_TARGET_ath79_generic_DEVICE_tplink_archer-c60-v2), y)
		CUSTOM_FILE_ARQ="tplink_archer-c60-v2"
	else ifeq ($(CONFIG_TARGET_ath79_generic_DEVICE_tplink_archer-c60-v3), y)
		CUSTOM_FILE_ARQ="tplink_archer-c60-v3"
	else ifeq ($(CONFIG_TARGET_ath79_generic_DEVICE_tplink_archer-c6-v2-us), y)
		CUSTOM_FILE_ARQ="tplink_archer-c6-v2US"
	else ifeq ($(CONFIG_TARGET_ath79_generic_DEVICE_tplink_archer-c7-v5), y)
		CUSTOM_FILE_ARQ="tplink_archer-c7-v5"
	else ifeq ($(CONFIG_TARGET_ramips_mt7620_DEVICE_tplink_ec220-g5-v2), y)
		CUSTOM_FILE_ARQ="tplink_ec220-g5-v2"
	else ifeq ($(CONFIG_TARGET_ath79_generic_DEVICE_dlink_covr-c1200-a1), y)
		CUSTOM_FILE_ARQ="dlink_covr-c1200-a1"
	else ifeq ($(CONFIG_TARGET_ramips_mt7620_DEVICE_dlink_dir-819-a1), y)
		CUSTOM_FILE_ARQ="tbs"
	else ifeq ($(CONFIG_TARGET_ar71xx_tiny_DEVICE_tl-wr740n-v4), y)
		CUSTOM_FILE_ARQ="tplink_tl-wr740n-v4-v5"
	else ifeq ($(CONFIG_TARGET_ar71xx_tiny_DEVICE_tl-wr740n-v5), y)
		CUSTOM_FILE_ARQ="tplink_tl-wr740n-v4-v5"
	else ifeq ($(CONFIG_TARGET_ar71xx_tiny_DEVICE_tl-wr740n-v6), y)
		CUSTOM_FILE_ARQ="tplink_tl-wr740n-v6"
	else ifeq ($(CONFIG_TARGET_ar71xx_tiny_DEVICE_tl-wr741nd-v4), y)
		CUSTOM_FILE_ARQ="tplink_tl-wr741n"
	else ifeq ($(CONFIG_TARGET_ar71xx_tiny_DEVICE_tl-wr841-v7), y)
		CUSTOM_FILE_ARQ="tplink_tl-wr841n-v7"
	else ifeq ($(CONFIG_TARGET_ar71xx_tiny_DEVICE_tl-wr841-v8), y)
		CUSTOM_FILE_ARQ="tplink_tl-wr841n-v8"
	else ifeq ($(CONFIG_TARGET_ar71xx_tiny_DEVICE_tl-wr841-v9), y)
		CUSTOM_FILE_ARQ="tplink_tl-wr841n-v8"
	else ifeq ($(CONFIG_TARGET_ath79_generic_DEVICE_tplink_tl-wr842n-v3), y)
		CUSTOM_FILE_ARQ="tplink_tl-wr842n"
	else ifeq ($(CONFIG_TARGET_ath79_generic_DEVICE_tplink_tl-wr2543-v1), y)
		CUSTOM_FILE_ARQ="tplink_tl-wr2543nd"
	else ifeq ($(CONFIG_TARGET_ath79_generic_DEVICE_tplink_tl-wdr4300-v1), y)
		CUSTOM_FILE_ARQ="tplink_tl-wdr4300"
	else ifeq ($(CONFIG_TARGET_ath79_generic_DEVICE_tplink_tl-wdr3600-v1), y)
		CUSTOM_FILE_ARQ="tplink_tl-wdr3600"
	else ifeq ($(CONFIG_TARGET_ramips_mt76x8_DEVICE_tl-wr840n-v4), y)
		CUSTOM_FILE_ARQ="tplink_tl-wr84Xn-v4"
	else ifeq ($(CONFIG_TARGET_ramips_mt76x8_DEVICE_tl-wr840n-v5), y)
		CUSTOM_FILE_ARQ="tplink_tl-wr84Xn-v5-v6"
	else ifeq ($(CONFIG_TARGET_ramips_mt76x8_DEVICE_tl-wr840n-v6), y)
		CUSTOM_FILE_ARQ="tplink_tl-wr84Xn-v5-v6"
	else ifeq ($(CONFIG_TARGET_ramips_mt76x8_DEVICE_tl-wr840n-v62), y)
		CUSTOM_FILE_ARQ="tplink_tl-wr84Xn-v62"
	else ifeq ($(CONFIG_TARGET_ramips_mt76x8_DEVICE_tl-wr849n-v4), y)
		CUSTOM_FILE_ARQ="tplink_tl-wr84Xn-v4"
	else ifeq ($(CONFIG_TARGET_ramips_mt76x8_DEVICE_tl-wr849n-v5), y)
		CUSTOM_FILE_ARQ="tplink_tl-wr84Xn-v5-v6"
	else ifeq ($(CONFIG_TARGET_ramips_mt76x8_DEVICE_tl-wr849n-v6), y)
		CUSTOM_FILE_ARQ="tplink_tl-wr84Xn-v5-v6"
	else ifeq ($(CONFIG_TARGET_ramips_mt76x8_DEVICE_tl-wr849n-v62), y)
		CUSTOM_FILE_ARQ="tplink_tl-wr84Xn-v62"
	else ifeq ($(CONFIG_TARGET_ar71xx_tiny_DEVICE_tl-wr940n-v4), y)
		CUSTOM_FILE_ARQ="tplink_tl-wr940n-v4-v5"
	else ifeq ($(CONFIG_TARGET_ar71xx_tiny_DEVICE_tl-wr940n-v5), y)
		CUSTOM_FILE_ARQ="tplink_tl-wr940n-v4-v5"
	else ifeq ($(CONFIG_TARGET_ar71xx_tiny_DEVICE_tl-wr940n-v6), y)
		CUSTOM_FILE_ARQ="tplink_tl-wr94Xn-v6"
	else ifeq ($(CONFIG_TARGET_ar71xx_tiny_DEVICE_tl-wr949n-v6), y)
		CUSTOM_FILE_ARQ="tplink_tl-wr94Xn-v6"
	else ifeq ($(CONFIG_TARGET_ar71xx_generic_DEVICE_tl-wdr3500-v1), y)
		CUSTOM_FILE_ARQ="tplink_tl-wdr3500"
	else ifeq ($(CONFIG_TARGET_ramips_mt7620_DEVICE_dlink_dwr-116-a1), y)
		CUSTOM_FILE_ARQ="dlink_dl-dwr116-a3"
	else ifeq ($(CONFIG_TARGET_ramips_mt7620_DEVICE_itlb-ncloud-v1), y)
		CUSTOM_FILE_ARQ="intelbras_ncloud-v1"
	else ifeq ($(CONFIG_TARGET_realtek_rtl8196e_DEVICE_GWR300N), y)
		CUSTOM_FILE_ARQ="greatek_gwr300-v1"
	else ifeq ($(CONFIG_TARGET_realtek_rtl8197f_DEVICE_GWR1200AC-V1), y)
		CUSTOM_FILE_ARQ="greatek_gwr1200-v1"
	else ifeq ($(CONFIG_TARGET_realtek_rtl8197f_DEVICE_GWR1200AC-V2), y)
		CUSTOM_FILE_ARQ="greatek_gwr1200-v2"
	else ifeq ($(CONFIG_TARGET_realtek_rtl8196e_DEVICE_RE172), y)
		CUSTOM_FILE_ARQ="multilaser_re172-v1"
	else ifeq ($(CONFIG_TARGET_realtek_rtl8197f_DEVICE_RE708), y)
		CUSTOM_FILE_ARQ="multilaser_re708-v1"
	else ifeq ($(CONFIG_TARGET_realtek_rtl8197f_DEVICE_MAXLINKAC1200G-V1), y)
		CUSTOM_FILE_ARQ="maxprint_maxlinkac1200g-v1"
	else ifeq ($(CONFIG_TARGET_realtek_rtl8197f_DEVICE_ACTIONRF1200), y)
		CUSTOM_FILE_ARQ="intelbras_rf1200-v1"
	else ifeq ($(CONFIG_TARGET_realtek_rtl8197f_DEVICE_ACTIONRG1200), y)
		CUSTOM_FILE_ARQ="intelbras_rg1200-v1"
	else ifeq ($(CONFIG_TARGET_realtek_rtl8197f_DEVICE_GF1200), y)
		CUSTOM_FILE_ARQ="intelbras_gf1200-v1"
	else ifeq ($(CONFIG_TARGET_realtek_rtl8197f_DEVICE_W51200F), y)
		CUSTOM_FILE_ARQ="intelbras_w51200f-v1"
	endif

WAN_PROTO=
	ifeq ($(CONFIG_FLASHMAN_WAN_PROTO_DHCP), y)
		WAN_PROTO="dhcp"
	else ifeq ($(CONFIG_FLASHMAN_WAN_PROTO_PPPOE), y)
		WAN_PROTO="pppoe"
	else
		WAN_PROTO="dhcp"
	endif

SSID_SUFFIX=
	ifeq ($(CONFIG_FLASHMAN_SSID_SUFFIX_LASTMAC), y)
		SSID_SUFFIX="lastmac"
	else ifeq ($(CONFIG_FLASHMAN_SSID_SUFFIX_NONE), y)
		SSID_SUFFIX="none"
	else
		SSID_SUFFIX="lastmac"
	endif

define Package/flashman-plugin/install

	$(CP) ./$(FILE_DIR)/* $(1)/
ifneq ($(CUSTOM_FILE_ARQ),)
	$(CP) ./custom-files/$(CUSTOM_FILE_ARQ).sh $(1)/usr/share/functions/custom_device.sh
endif

ifeq ($(CONFIG_TARGET_ramips), y)
	$(INSTALL_DIR) $(1)/lib/wifi $(1)/lib/netifd/wireless
	$(INSTALL_DATA) ./mtkwifi/wifi/rtwifi.sh $(1)/lib/wifi
	$(INSTALL_BIN) ./mtkwifi/netifd/wireless/rtwifi.sh $(1)/lib/netifd/wireless
	$(CP) ./driver/rtwifi.sh $(1)/usr/share/functions/custom_wireless_driver.sh
else ifneq ($(filter \
	$(CONFIG_TARGET_ath79_generic_DEVICE_tplink_archer-c60-v3)\
	$(CONFIG_TARGET_ath79_generic_DEVICE_tplink_archer-c60-v2)\
	$(CONFIG_TARGET_ath79_generic_DEVICE_tplink_archer-c6-v2-us)\
,y),)
	$(INSTALL_DIR) $(1)/lib/wifi $(1)/lib/netifd/wireless $(1)/lib/firmware $(1)/lib/preinit/
	$(INSTALL_DATA) ./qcawifi/wifi/qcawifi.sh $(1)/lib/wifi
	$(INSTALL_DATA) ./qcawifi/wifi/qcawifi_functions.sh $(1)/lib/wifi
	$(INSTALL_BIN)  ./qcawifi/netifd/wireless/qcawifi.sh $(1)/lib/netifd/wireless
	$(CP) ./driver/qcawifi.sh $(1)/usr/share/functions/custom_wireless_driver.sh
	$(INSTALL_DATA) ./qcawifi/preinit/82_downloading_caldata $(1)/lib/preinit/
else
	$(CP) ./driver/mac80211.sh $(1)/usr/share/functions/custom_wireless_driver.sh
endif

	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/anlix-mqtt $(1)/usr/bin/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/pk $(1)/usr/bin/

ifeq ($(CONFIG_TARGET_realtek_rtl8197f_DEVICE_W51200F), y)
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/anlix-flash-utils $(1)/usr/bin/
endif

ifeq ($(CONFIG_TARGET_realtek_rtl8197f_DEVICE_GWR1200AC-V2), y)
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/anlix-flash-utils $(1)/usr/bin/
endif

	mkdir -p $(1)/usr/share
	echo 'FLM_SSID_SUFFIX=$(SSID_SUFFIX)' >>$(1)/usr/share/flashman_init.conf
	echo 'FLM_SSID=$(CONFIG_FLASHMAN_WIFI_SSID)' >>$(1)/usr/share/flashman_init.conf
	echo 'FLM_PASSWD=$(CONFIG_FLASHMAN_WIFI_PASSWD)' >>$(1)/usr/share/flashman_init.conf
	echo 'FLM_24_CHANNEL=$(CONFIG_FLASHMAN_WIFI_CHANNEL)' >>$(1)/usr/share/flashman_init.conf
	echo 'FLM_24_BAND=$(CONFIG_FLASHMAN_WIFI_BAND)' >>$(1)/usr/share/flashman_init.conf
	echo 'FLM_50_CHANNEL=$(CONFIG_FLASHMAN_WIFI_5GHZ_CHANNEL)' >>$(1)/usr/share/flashman_init.conf
	echo 'FLM_DISASSOC_LOW_ACK=$(CONFIG_FLASHMAN_WIFI_DISASSOC_LOW_ACK)' >>$(1)/usr/share/flashman_init.conf
	echo 'FLM_RELID=$(CONFIG_FLASHMAN_RELEASE_ID)' >>$(1)/usr/share/flashman_init.conf
	echo 'FLM_SVADDR=$(CONFIG_FLASHMAN_SERVER_ADDR)' >>$(1)/usr/share/flashman_init.conf
	echo 'NTP_SVADDR=$(CONFIG_NTP_SERVER_ADDR)' >>$(1)/usr/share/flashman_init.conf
	echo 'NTP_SVADDR_2=$(CONFIG_NTP_SERVER_ADDR_2)' >>$(1)/usr/share/flashman_init.conf
	echo 'NTP_SVADDR_3=$(CONFIG_NTP_SERVER_ADDR_3)' >>$(1)/usr/share/flashman_init.conf
	echo 'NTP_SVADDR_4=$(CONFIG_NTP_SERVER_ADDR_4)' >>$(1)/usr/share/flashman_init.conf
	echo 'FLM_WAN_PROTO=$(WAN_PROTO)' >>$(1)/usr/share/flashman_init.conf
	echo 'FLM_WAN_MTU=$(CONFIG_FLASHMAN_WAN_MTU)' >>$(1)/usr/share/flashman_init.conf
	echo 'FLM_WAN_IPV6_ENABLED=$(CONFIG_FLASHMAN_WAN_IPV6_ENABLED)' >>$(1)/usr/share/flashman_init.conf
	echo 'FLM_LAN_SUBNET=$(CONFIG_FLASHMAN_LAN_SUBNET)' >>$(1)/usr/share/flashman_init.conf
	echo 'FLM_LAN_NETMASK=$(CONFIG_FLASHMAN_LAN_NETMASK)' >>$(1)/usr/share/flashman_init.conf
	echo 'FLM_LAN_IPV6_PREFIX=$(CONFIG_FLASHMAN_LAN_IPV6_PREFIX)' >>$(1)/usr/share/flashman_init.conf
	echo 'FLM_DHCP_NOPROXY=$(CONFIG_FLASHMAN_DHCP_NOPROXY)' >>$(1)/usr/share/flashman_init.conf
	echo 'FLM_DO_DHCP_RENEW_ON_DISCONNECT=$(CONFIG_FLASHMAN_DO_DHCP_RENEW_ON_DISCONNECT)' >>$(1)/usr/share/flashman_init.conf
	echo 'FLM_DHCP_REBIND=$(CONFIG_FLASHMAN_DHCP_REBIND)' >>$(1)/usr/share/flashman_init.conf
	echo 'MQTT_PORT=$(CONFIG_MQTT_PORT)' >>$(1)/usr/share/flashman_init.conf
	echo 'FLM_CLIENT_ORG=$(CONFIG_FLASHMAN_CLIENT_ORG)' >>$(1)/usr/share/flashman_init.conf
	echo 'FLM_WAN_PPPOE_USER=$(CONFIG_FLASHMAN_PPPOE_USER)' >>$(1)/usr/share/flashman_init.conf
	echo 'FLM_WAN_PPPOE_PASSWD=$(CONFIG_FLASHMAN_PPPOE_PASSWD)' >>$(1)/usr/share/flashman_init.conf
	echo 'FLM_WAN_PPPOE_SERVICE=$(CONFIG_FLASHMAN_PPPOE_SERVICE)' >>$(1)/usr/share/flashman_init.conf

	echo 'FLM_USE_AUTH_SVADDR=$(CONFIG_FLASHMAN_USE_AUTH_SERVER)' >>$(1)/usr/share/flashman_init.conf
	echo 'FLM_CONNECTIVITY_SVADDRS_LIST=$(CONFIG_CONNECTIVITY_SVADDRS_LIST)' >>$(1)/usr/share/flashman_init.conf

	echo 'FLM_REAUTH_TIME=$(CONFIG_FLASHMAN_REAUTH_TIME)' >>$(1)/usr/share/flashman_init.conf

ifeq ($(CONFIG_FLASHMAN_USE_AUTH_SERVER), y)
	echo 'FLM_AUTH_SVADDR=$(CONFIG_FLASHMAN_AUTH_SERVER_ADDR)' >>$(1)/usr/share/flashman_init.conf
	echo 'FLM_CLIENT_SECRET=$(CONFIG_FLASHMAN_CLIENT_SECRET)' >>$(1)/usr/share/flashman_init.conf
endif

ifeq ($(CONFIG_PREFIX_DELEGATION_RELAY), y)
	echo 'FLM_PREFIX_DELEGATION_TYPE="relay"' >>$(1)/usr/share/flashman_init.conf
else
	echo 'FLM_PREFIX_DELEGATION_TYPE="server"' >>$(1)/usr/share/flashman_init.conf
endif

	echo $(PKG_VERSION) > $(1)/etc/anlix_version

	mkdir -p $(1)/etc/dropbear
	cat $(CONFIG_FLASHMAN_KEYS_PATH)/$(CONFIG_FLASHMAN_PUBKEY_FNAME) >>$(1)/etc/dropbear/authorized_keys
	chmod 0600 $(1)/etc/dropbear/authorized_keys

	cat $(CONFIG_FLASHMAN_KEYS_PATH)/$(CONFIG_PROVIDER_PUBKEY_FNAME) >>$(1)/etc/provider.pubkey
	chmod 0600 $(1)/etc/provider.pubkey

endef

$(eval $(call BuildPackage,flashman-plugin))
