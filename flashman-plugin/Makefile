#
# Copyright (C) 2017-2017 LAND/COPPE/UFRJ
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=flasman-plugin
PKG_VERSION:=0.5.1
PKG_RELEASE:=1

PKG_LICENSE:=GPL
PKG_LICENSE_FILES:=COPYING

PKG_BUILD_PARALLEL:=1
PKG_BUILD_DIR := $(BUILD_DIR)/$(PKG_NAME)

PKG_CONFIG_DEPENDS:= \
	CONFIG_FLASHMAN_WIFI_SSID \
	CONFIG_FLASHMAN_WIFI_PASSWD \
	CONFIG_FLASHMAN_WIFI_CHANNEL \
	CONFIG_FLASHMAN_RELEASE_ID \
	CONFIG_FLASHMAN_CLIENT_ORG

include $(INCLUDE_DIR)/package.mk

define Package/flashman-plugin'/Default
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
			+zabbix-agentd \
			+(!TARGET_x86&&!TARGET_x86_64):zabbix-extra-mac80211 \
			+zabbix-extra-network \
			+zabbix-extra-wifi \
			+libmbedtls
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
	
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/anlix-mqtt $(1)/usr/bin/

	mkdir -p $(1)/usr/share
	echo 'FLM_SSID_SUFFIX=$(SSID_SUFFIX)' >>$(1)/usr/share/flashman_init.conf
	echo 'FLM_SSID=$(CONFIG_FLASHMAN_WIFI_SSID)' >>$(1)/usr/share/flashman_init.conf
	echo 'FLM_PASSWD=$(CONFIG_FLASHMAN_WIFI_PASSWD)' >>$(1)/usr/share/flashman_init.conf
	echo 'FLM_24_CHANNEL=$(CONFIG_FLASHMAN_WIFI_CHANNEL)' >>$(1)/usr/share/flashman_init.conf
	echo 'FLM_RELID=$(CONFIG_FLASHMAN_RELEASE_ID)' >>$(1)/usr/share/flashman_init.conf
	echo 'FLM_SVADDR=$(CONFIG_FLASHMAN_SERVER_ADDR)' >>$(1)/usr/share/flashman_init.conf
	echo 'NTP_SVADDR=$(CONFIG_NTP_SERVER_ADDR)' >>$(1)/usr/share/flashman_init.conf
	echo 'FLM_WAN_PROTO=$(WAN_PROTO)' >>$(1)/usr/share/flashman_init.conf
	echo 'FLM_WAN_MTU=$(CONFIG_FLASHMAN_WAN_MTU)' >>$(1)/usr/share/flashman_init.conf
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

	echo 'ZBX_SEND_DATA=$(CONFIG_ZABBIX_SEND_DATA)' >>$(1)/usr/share/flashman_init.conf
	echo 'ZBX_SVADDR=$(CONFIG_ZABBIX_SERVER_ADDR)' >>$(1)/usr/share/flashman_init.conf

	mkdir -p $(1)/etc/dropbear
	cat $(CONFIG_FLASHMAN_KEYS_PATH)/$(CONFIG_FLASHMAN_PUBKEY_FNAME) >>$(1)/etc/dropbear/authorized_keys
	chmod 0600 $(1)/etc/dropbear/authorized_keys

endef

$(eval $(call BuildPackage,flashman-plugin))
