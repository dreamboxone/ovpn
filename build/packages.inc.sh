#!/bin/sh
#
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 dreamboxone <https://t.me/routekernel1>
# Part of ovpn - https://github.com/dreamboxone/ovpn
#
# packages.inc.sh - what goes into a package, shared by the .apk and .ipk
# builders so the two formats can never drift apart.

VERSION=1.0.1
RELEASE=3
PKGVER="$VERSION-r$RELEASE"
LICENSE="GPL-3.0-only"
URL="https://github.com/dreamboxone/ovpn"
MAINTAINER="routekernel <https://t.me/routekernel1>"

OVPN_DEPS="jshn libubox curl nftables kmod-nft-tproxy ip-full"
LUCI_DEPS="ovpn luci-base"

OVPN_DESC="Transparent proxy client for OpenWrt built on Xray. Refreshes its server list every quarter of an hour, times a real HTTP request through every server and connects through the fastest one."
LUCI_DESC="Web interface for ovpn: connect, disconnect, and the state of the current connection."

# Every quarter of an hour. Reading the list is one small request, and the
# script decides for itself whether measuring again is worth doing.
CRON_LINE='*/15 * * * * /usr/libexec/ovpn-refresh >/dev/null 2>&1'

# stage_ovpn <staging-root> <source-root> <xray-binary>
stage_ovpn() {
	work="$1"; root="$2"; core="$3"
	f="$root/package/ovpn/files"
	i="$work/ovpn"

	# Our own copy of the core lives under /usr/libexec/ovpn. /usr/bin/xray
	# belongs to OpenWrt's xray-core package, which PassWall2 and others pull
	# in, and claiming that path makes this package refuse to install on any
	# router that already has one.
	install -d "$i/usr/libexec/ovpn" "$i/etc/config" "$i/etc/init.d" \
	           "$i/usr/libexec/rpcd" "$i/etc/ovpn"
	install -m 0755 "$core"              "$i/usr/libexec/ovpn/xray"
	install -m 0644 "$f/ovpn.config"     "$i/etc/config/ovpn"
	install -m 0755 "$f/ovpn.init"       "$i/etc/init.d/ovpn"
	install -m 0755 "$f/ovpn-update"     "$i/usr/libexec/ovpn-update"
	install -m 0755 "$f/ovpn-connect"    "$i/usr/libexec/ovpn-connect"
	install -m 0755 "$f/ovpn-refresh"    "$i/usr/libexec/ovpn-refresh"
	install -m 0755 "$f/ovpn-parse"      "$i/usr/libexec/ovpn-parse"
	install -m 0644 "$f/ovpn-common.sh"   "$i/usr/libexec/ovpn-common.sh"
	install -m 0755 "$f/ovpn-mkconfig"   "$i/usr/libexec/ovpn-mkconfig"
	install -m 0755 "$f/ovpn-rules"      "$i/usr/libexec/ovpn-rules"
	install -m 0755 "$f/luci.ovpn"       "$i/usr/libexec/rpcd/luci.ovpn"

	ver="$(dirname "$core")/xray-version.txt"
	[ -s "$ver" ] && install -m 0644 "$ver" "$i/etc/ovpn/xray-version"

	echo "/etc/config/ovpn" > "$work/ovpn.conffiles"

	cat > "$work/ovpn.postinst" <<EOF
mkdir -p /etc/ovpn /var/run/ovpn
# one crontab entry, and only one however often this package is reinstalled
touch /etc/crontabs/root
sed -i '\|/usr/libexec/ovpn-|d' /etc/crontabs/root
echo '$CRON_LINE' >> /etc/crontabs/root
# Every one of these takes a procd lock, and a lock held by something that
# died leaves the call waiting for good - which would strand the install
# half done and make the package impossible to remove afterwards. Bound
# them: none of this is worth failing an installation over.
timeout 15 /etc/init.d/cron reload >/dev/null 2>&1 || true
timeout 15 /etc/init.d/rpcd reload >/dev/null 2>&1 || true
exit 0
EOF

	cat > "$work/ovpn.prerm" <<'EOF'
timeout 20 /etc/init.d/ovpn stop >/dev/null 2>&1 || true
timeout 15 /etc/init.d/ovpn disable >/dev/null 2>&1 || true
sed -i '\|/usr/libexec/ovpn-|d' /etc/crontabs/root 2>/dev/null
timeout 15 /etc/init.d/cron reload >/dev/null 2>&1 || true
exit 0
EOF

}

# stage_luci <staging-root> <source-root>
stage_luci() {
	work="$1"; root="$2"
	l="$root/package/luci-app-ovpn/root"
	i="$work/luci-app-ovpn"

	install -d "$i/www/luci-static/resources/view/ovpn" \
	           "$i/usr/share/luci/menu.d" "$i/usr/share/rpcd/acl.d"
	install -m 0644 "$l/www/luci-static/resources/view/ovpn/overview.js" \
		"$i/www/luci-static/resources/view/ovpn/overview.js"
	install -m 0644 "$l/usr/share/luci/menu.d/luci-app-ovpn.json" \
		"$i/usr/share/luci/menu.d/luci-app-ovpn.json"
	install -m 0644 "$l/usr/share/rpcd/acl.d/luci-app-ovpn.json" \
		"$i/usr/share/rpcd/acl.d/luci-app-ovpn.json"

	cat > "$work/luci-app-ovpn.postinst" <<'EOF'
rm -f /tmp/luci-indexcache* 2>/dev/null
rm -rf /tmp/luci-modulecache 2>/dev/null
timeout 15 /etc/init.d/rpcd reload >/dev/null 2>&1 || true
timeout 15 /etc/init.d/uhttpd restart >/dev/null 2>&1 || true
exit 0
EOF
}
