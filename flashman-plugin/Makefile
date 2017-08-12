#
# Copyright (C) 2017-2017 LAND/COPPE/UFRJ
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=flasman-plugin
PKG_VERSION:=0.000
PKG_RELEASE:=1

PKG_LICENSE:=GPL
PKG_LICENSE_FILES:=COPYING

PKG_BUILD_PARALLEL:=1

PKG_CONFIG_DEPENDS:= \
	CONFIG_FLASHMAN_WIFI_SSID \
	CONFIG_FLASHMAN_WIFI_PASSWD \
	CONFIG_FLASHMAN_RELEASE_ID

include $(INCLUDE_DIR)/package.mk

define Package/flashman-plugin'/Default
	SECTION:=utils
	CATEGORY:=Utilities
	PKGARCH:=all
	MAINTAINER:=Guilherme da Silva Senges <guisenges@land.ufrj.br>
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
					 +luci \
					 +iputils-ping \
					 +iputils-ping6 \
					 +zabbix-agentd \
					 +zabbix-extra-mac80211 \
					 +zabbix-extra-network \
					 +zabbix-extra-wifi
	MENU:=1
endef

define Package/flashman-plugin/config
	source "$(SOURCE)/Config.in"
endef

define Build/Compile
endef

FILE_DIR=
	ifeq ($(CONFIG_USE_DEFAULT_FLAG), y)
		FILE_DIR="files"
	endif

define Package/flashman-plugin/install
	$(CP) ./$(FILE_DIR)/* $(1)/

	mkdir -p $(1)/usr/share
	echo 'FLM_SSID=$(CONFIG_FLASHMAN_WIFI_SSID)' >>$(1)/usr/share/flashman_init.conf
	echo 'FLM_PASSWD=$(CONFIG_FLASHMAN_WIFI_PASSWD)' >>$(1)/usr/share/flashman_init.conf
	echo 'FLM_RELID=$(CONFIG_FLASHMAN_RELEASE_ID)' >>$(1)/usr/share/flashman_init.conf
	echo 'FLM_SVADDR=$(CONFIG_FLASHMAN_SERVER_ADDR)' >>$(1)/usr/share/flashman_init.conf
	echo 'ZBX_SVADDR=$(CONFIG_ZABBIX_SERVER_ADDR)' >>$(1)/usr/share/flashman_init.conf
	echo 'NTP_SVADDR=$(CONFIG_NTP_SERVER_ADDR)' >>$(1)/usr/share/flashman_init.conf

	mkdir -p $(1)/etc/dropbear
	cat $(CONFIG_FLASHMAN_KEYS_PATH)/$(CONFIG_FLASHMAN_PUBKEY_FNAME) >>$(1)/etc/dropbear/authorized_keys
	chmod 0600 $(1)/etc/dropbear/authorized_keys

endef

$(eval $(call BuildPackage,flashman-plugin))
