include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-vlanwizard
PKG_VERSION:=1.0
PKG_RELEASE:=1

PKG_LICENSE:=GPL-2.0
PKG_MAINTAINER:=Mohmmed Fayez

include $(INCLUDE_DIR)/package.mk

define Package/luci-app-vlanwizard
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  TITLE:=VLAN Wizard for LuCI
  DEPENDS:=+luci-base +rpcd
endef

define Package/luci-app-vlanwizard/description
  Quick Programming Wizard for OpenWrt
endef

define Build/Compile
endef

define Package/luci-app-vlanwizard/install
	# 1. نسخ ملفات Lua (Controller)
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/controller
	$(INSTALL_DATA) ./luasrc/controller/vlanwizard.lua $(1)/usr/lib/lua/luci/controller/
	
	# 2. نسخ ملفات الويب (JS)
	$(INSTALL_DIR) $(1)/www/luci-static/resources/view/vlanwizard
	$(INSTALL_DATA) ./htdocs/luci-static/resources/view/vlanwizard/main.js $(1)/www/luci-static/resources/view/vlanwizard/
	
	# 3. نسخ ملفات الإعدادات والتشغيل
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./root/etc/config/wizard $(1)/etc/config/
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./root/etc/init.d/wizard $(1)/etc/init.d/
	
	# 4. نسخ ملفات الصلاحيات
	$(INSTALL_DIR) $(1)/usr/share/rpcd/acl.d
	$(INSTALL_DATA) ./root/usr/share/rpcd/acl.d/luci-app-vlanwizard.json $(1)/usr/share/rpcd/acl.d/
endef

$(eval $(call BuildPackage,luci-app-vlanwizard))
