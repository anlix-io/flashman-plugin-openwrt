include $(TOPDIR)/rules.mk

PKG_NAME:=flasman-plugin
PKG_VERSION:=0.000
PKG_RELEASE:=1

PKG_MAINTAINER:=Guilherme da Silva Senges
include $(INCLUDE_DIR)/package.mk

define Package/flashman-plugin/Default
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=Install flashman-plugin
  PKGARCH:=all
endef

define Package/flashman-plugin
$(call Package/flashman-plugin/Default)
  DEPENDS:=+curl \
           +zabbix-agentd \
					 +zabbix-extra-mac80211 \
					 +zabbix-extra-network \
					 +zabbix-extra-wifi
  MAKE:=1
endef

define Package/flashman-plugin/config
  source "$(SOURCE)/Config.in"
endef

define Package/flashman-plugin/description
  Dependencies and scripts for communicating with FlashMan server
endef

define Build/Compile
endef

FILE_DIR=
  ifeq ($(CONFIG_USE_DEFAULT_FLAG), y)
    FILE_DIR="files"
  endif

define Package/flashman-plugin/install
	$(CP) ./$(FILE_DIR)/* $(1)/
endef

$(eval $(call BuildPackage,flashman-plugin))
