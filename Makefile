#
# Copyright (C) 2017-2017 LAND/COPPE/UFRJ
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=flasman-plugin
PKG_VERSION:=0.21.0
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
	CONFIG_FLASHMAN_RELEASE_ID \
	CONFIG_FLASHMAN_CLIENT_ORG

include $(INCLUDE_DIR)/package.mk

define Package/flashman-plugin/Default
	SECTION:=utils
	CATEGORY:=Utilities
	PKGARCH:=all
	MAINTAINER:=Guilherme da Silva Senges <guilherme@anlix.io>
endef

define Package/flashman-plugin/description
	Dependencies and scripts for communicating with FlashMan server
endef

define Package/flashman-plugin
	$(call Package/flashman-plugin/Default)
	SECTION:=utils
	CATEGORY:=Utilities
	TITLE:=Install flashman-plugin
	DEPENDS:=+curl \
			+iputils-ping \
			+iputils-ping6 \
			+wireless-tools \
			+uhttpd \
			+uhttpd-mod-lua \
			+px5g-mbedtls \
			+libustream-mbedtls \
			+libuuid \
			+libcares \
			+rpcd \
			+libuci-lua \
			+libubus-lua \
			+libmbedtls \
			+iptables-mod-conntrack-extra \
			+anlix-miniupnpd
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

CUSTOM_FILE_DIR=
	ifeq ($(CONFIG_TARGET_ramips_mt76x8_DEVICE_archer-c20-v4), y)
		CUSTOM_FILE_DIR="custom-files/archer-c20-v4"
	else ifeq ($(CONFIG_TARGET_ramips_mt76x8_DEVICE_archer-c20-v5), y)
		CUSTOM_FILE_DIR="custom-files/archer-c20-v5"
	else ifeq ($(CONFIG_TARGET_ramips_mt7620_DEVICE_ArcherC5v4), y)
		CUSTOM_FILE_DIR="custom-files/archer-c5-v4"
	else ifeq ($(CONFIG_TARGET_ramips_mt76x8_DEVICE_archer-c50-v4), y)
		CUSTOM_FILE_DIR="custom-files/archer-c50-v4"
	else ifeq ($(CONFIG_TARGET_ar71xx_generic_DEVICE_archer-c60-v2), y)
		CUSTOM_FILE_DIR="custom-files/archer-c60-v2"
	else ifeq ($(CONFIG_TARGET_ramips_mt7620_DEVICE_dl-dwr116-a3), y)
		CUSTOM_FILE_DIR="custom-files/dl-dwr116-a3"
	else ifeq ($(CONFIG_TARGET_ramips_mt7620_DEVICE_itlb-ncloud-v1), y)
		CUSTOM_FILE_DIR="custom-files/itlb-ncloud-v1"
	else ifeq ($(CONFIG_TARGET_ramips_mt7620_DEVICE_dir-819-a1), y)
		CUSTOM_FILE_DIR="custom-files/dir-819-a1"
	else ifeq ($(CONFIG_TARGET_ar71xx_tiny_DEVICE_tl-wr741nd-v4), y)
		CUSTOM_FILE_DIR="custom-files/tl-wr741nd-v4"
	else ifeq ($(CONFIG_TARGET_ar71xx_tiny_DEVICE_tl-wr841-v7), y)
		CUSTOM_FILE_DIR="custom-files/tl-wr841-v7"
	else ifeq ($(CONFIG_TARGET_ar71xx_tiny_DEVICE_tl-wr841-v8), y)
		CUSTOM_FILE_DIR="custom-files/tl-wr841-v8"
	else ifeq ($(CONFIG_TARGET_ar71xx_generic_DEVICE_tl-wr842n-v3), y)
		CUSTOM_FILE_DIR="custom-files/tl-wr842n-v3"
	else ifeq ($(CONFIG_TARGET_ar71xx_generic_DEVICE_tl-wdr3500-v1), y)
		CUSTOM_FILE_DIR="custom-files/tl-wdr3500-v1"
	else ifeq ($(CONFIG_TARGET_ar71xx_generic_DEVICE_tl-wdr3600-v1), y)
		CUSTOM_FILE_DIR="custom-files/tl-wdr3600-v1"
	else ifeq ($(CONFIG_TARGET_ar71xx_generic_DEVICE_tl-wdr4300-v1), y)
		CUSTOM_FILE_DIR="custom-files/tl-wdr4300-v1"
	else ifeq ($(CONFIG_TARGET_ar71xx_generic_DEVICE_tl-wr2543-v1), y)
		CUSTOM_FILE_DIR="custom-files/tl-wr2543-v1"
	else ifeq ($(CONFIG_TARGET_ramips_mt76x8_DEVICE_tl-wr840n-v4), y)
		CUSTOM_FILE_DIR="custom-files/tl-wr840n-v4"
	else ifeq ($(CONFIG_TARGET_ramips_mt76x8_DEVICE_tl-wr840n-v5preset), y)
		CUSTOM_FILE_DIR="custom-files/tl-wr840n-v5preset"
	else ifeq ($(CONFIG_TARGET_ramips_mt76x8_DEVICE_tl-wr840n-v5), y)
		CUSTOM_FILE_DIR="custom-files/tl-wr840n-v5"
	else ifeq ($(CONFIG_TARGET_ramips_mt76x8_DEVICE_tl-wr840n-v6), y)
		CUSTOM_FILE_DIR="custom-files/tl-wr840n-v6"
	else ifeq ($(CONFIG_TARGET_ramips_mt76x8_DEVICE_tl-wr840n-v62), y)
		CUSTOM_FILE_DIR="custom-files/tl-wr840n-v62"
	else ifeq ($(CONFIG_TARGET_ramips_mt76x8_DEVICE_tl-wr840n-v6preset), y)
		CUSTOM_FILE_DIR="custom-files/tl-wr840n-v6preset"
	else ifeq ($(CONFIG_TARGET_ramips_mt76x8_DEVICE_tl-wr845n-v3), y)
		CUSTOM_FILE_DIR="custom-files/tl-wr845n-v3"
	else ifeq ($(CONFIG_TARGET_ramips_mt76x8_DEVICE_tl-wr845n-v4), y)
		CUSTOM_FILE_DIR="custom-files/tl-wr845n-v4"
	else ifeq ($(CONFIG_TARGET_ramips_mt76x8_DEVICE_tl-wr849n-v4), y)
		CUSTOM_FILE_DIR="custom-files/tl-wr849n-v4"
	else ifeq ($(CONFIG_TARGET_ramips_mt76x8_DEVICE_tl-wr849n-v5), y)
		CUSTOM_FILE_DIR="custom-files/tl-wr849n-v5"
	else ifeq ($(CONFIG_TARGET_ramips_mt76x8_DEVICE_tl-wr849n-v6), y)
		CUSTOM_FILE_DIR="custom-files/tl-wr849n-v6"
	else ifeq ($(CONFIG_TARGET_ramips_mt76x8_DEVICE_tl-wr849n-v62), y)
		CUSTOM_FILE_DIR="custom-files/tl-wr849n-v62"
	else ifeq ($(CONFIG_TARGET_ar71xx_tiny_DEVICE_tl-wr940n-v6), y)
		CUSTOM_FILE_DIR="custom-files/tl-wr940n-v6"
	else ifeq ($(CONFIG_TARGET_ar71xx_tiny_DEVICE_tl-wr949n-v6), y)
		CUSTOM_FILE_DIR="custom-files/tl-wr949n-v6"
	else ifeq ($(CONFIG_TARGET_realtek_rtl8197d_DEVICE_DIR815D1), y)
		CUSTOM_FILE_DIR="custom-files/dir-815-d1"
	else ifeq ($(CONFIG_TARGET_realtek_rtl8196e_DEVICE_GWR300N), y)
		CUSTOM_FILE_DIR="custom-files/gwr-300-v1"
	else ifeq ($(CONFIG_TARGET_realtek_rtl8196e_DEVICE_RE172), y)
		CUSTOM_FILE_DIR="custom-files/re172-v1"
	else
		CUSTOM_FILE_DIR="custom-files/default"
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
	$(CP) ./$(CUSTOM_FILE_DIR)/* $(1)/
	
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/anlix-mqtt $(1)/usr/bin/

	mkdir -p $(1)/usr/share
	echo 'FLM_SSID_SUFFIX=$(SSID_SUFFIX)' >>$(1)/usr/share/flashman_init.conf
	echo 'FLM_SSID=$(CONFIG_FLASHMAN_WIFI_SSID)' >>$(1)/usr/share/flashman_init.conf
	echo 'FLM_PASSWD=$(CONFIG_FLASHMAN_WIFI_PASSWD)' >>$(1)/usr/share/flashman_init.conf
	echo 'FLM_24_CHANNEL=$(CONFIG_FLASHMAN_WIFI_CHANNEL)' >>$(1)/usr/share/flashman_init.conf
	echo 'FLM_24_BAND=$(CONFIG_FLASHMAN_WIFI_BAND)' >>$(1)/usr/share/flashman_init.conf
	echo 'FLM_50_CHANNEL=$(CONFIG_FLASHMAN_WIFI_5GHZ_CHANNEL)' >>$(1)/usr/share/flashman_init.conf
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
	echo 'MQTT_PORT=$(CONFIG_MQTT_PORT)' >>$(1)/usr/share/flashman_init.conf
	echo 'FLM_CLIENT_ORG=$(CONFIG_FLASHMAN_CLIENT_ORG)' >>$(1)/usr/share/flashman_init.conf

ifeq ($(WAN_PROTO), "pppoe")
	echo 'FLM_WAN_PPPOE_USER=$(CONFIG_FLASHMAN_PPPOE_USER)' >>$(1)/usr/share/flashman_init.conf
	echo 'FLM_WAN_PPPOE_PASSWD=$(CONFIG_FLASHMAN_PPPOE_PASSWD)' >>$(1)/usr/share/flashman_init.conf
	echo 'FLM_WAN_PPPOE_SERVICE=$(CONFIG_FLASHMAN_PPPOE_SERVICE)' >>$(1)/usr/share/flashman_init.conf
endif

	echo 'FLM_USE_AUTH_SVADDR=$(CONFIG_FLASHMAN_USE_AUTH_SERVER)' >>$(1)/usr/share/flashman_init.conf

ifeq ($(CONFIG_FLASHMAN_USE_AUTH_SERVER), y)
	echo 'FLM_AUTH_SVADDR=$(CONFIG_FLASHMAN_AUTH_SERVER_ADDR)' >>$(1)/usr/share/flashman_init.conf
	echo 'FLM_CLIENT_SECRET=$(CONFIG_FLASHMAN_CLIENT_SECRET)' >>$(1)/usr/share/flashman_init.conf
endif

	echo 'ZBX_SUPPORT=$(CONFIG_ZABBIX_SUPPORT)' >>$(1)/usr/share/flashman_init.conf

	echo $(PKG_VERSION) > $(1)/etc/anlix_version

	mkdir -p $(1)/etc/dropbear
	cat $(CONFIG_FLASHMAN_KEYS_PATH)/$(CONFIG_FLASHMAN_PUBKEY_FNAME) >>$(1)/etc/dropbear/authorized_keys
	chmod 0600 $(1)/etc/dropbear/authorized_keys

endef

$(eval $(call BuildPackage,flashman-plugin))
