# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 dreamboxone <https://t.me/routekernel1>
# Part of ovpn - https://github.com/dreamboxone/ovpn

include $(TOPDIR)/rules.mk

PKG_NAME:=ovpn
PKG_VERSION:=1.0.0
PKG_RELEASE:=9

PKG_MAINTAINER:=routekernel <https://t.me/routekernel1>
PKG_LICENSE:=GPL-3.0-only

include $(INCLUDE_DIR)/package.mk

define Package/ovpn
  SECTION:=net
  CATEGORY:=Network
  TITLE:=Transparent proxy client built on Xray
  URL:=https://github.com/dreamboxone/ovpn
  DEPENDS:=+jshn +libubox +curl +nftables +kmod-nft-tproxy +ip-full
endef

define Package/ovpn/description
 Sends every LAN device through a tunnel. Refreshes its server list daily,
 times a complete HTTP request through each server and connects through
 whichever answered fastest.
endef

define Package/ovpn/conffiles
/etc/config/ovpn
endef

define Build/Compile
endef

define Package/ovpn/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_DIR) $(1)/usr/libexec/ovpn
	$(INSTALL_BIN) ./files/../../../prebuilt/$(ARCH_PACKAGES)/xray $(1)/usr/libexec/ovpn/xray

	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DATA) ./files/ovpn.config $(1)/etc/config/ovpn

	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/ovpn.init $(1)/etc/init.d/ovpn

	$(INSTALL_DIR) $(1)/usr/libexec
	$(INSTALL_BIN) ./files/ovpn-update   $(1)/usr/libexec/ovpn-update
	$(INSTALL_BIN) ./files/ovpn-connect  $(1)/usr/libexec/ovpn-connect
	$(INSTALL_BIN) ./files/ovpn-parse    $(1)/usr/libexec/ovpn-parse
	$(INSTALL_DATA) ./files/ovpn-common.sh $(1)/usr/libexec/ovpn-common.sh
	$(INSTALL_BIN) ./files/ovpn-mkconfig $(1)/usr/libexec/ovpn-mkconfig
	$(INSTALL_BIN) ./files/ovpn-rules    $(1)/usr/libexec/ovpn-rules

	$(INSTALL_DIR) $(1)/usr/libexec/rpcd
	$(INSTALL_BIN) ./files/luci.ovpn $(1)/usr/libexec/rpcd/luci.ovpn

	$(INSTALL_DIR) $(1)/etc/ovpn
endef

define Package/ovpn/postinst
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] && exit 0
mkdir -p /etc/ovpn /var/run/ovpn
touch /etc/crontabs/root
sed -i '\|/usr/libexec/ovpn-update|d' /etc/crontabs/root
echo '0 21 * * * /usr/libexec/ovpn-update update >/dev/null 2>&1' >> /etc/crontabs/root
/etc/init.d/cron reload >/dev/null 2>&1
/etc/init.d/rpcd reload >/dev/null 2>&1
exit 0
endef

define Package/ovpn/prerm
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] && exit 0
/etc/init.d/ovpn stop >/dev/null 2>&1
/etc/init.d/ovpn disable >/dev/null 2>&1
sed -i '\|/usr/libexec/ovpn-update|d' /etc/crontabs/root 2>/dev/null
/etc/init.d/cron reload >/dev/null 2>&1
exit 0
endef

$(eval $(call BuildPackage,ovpn))
