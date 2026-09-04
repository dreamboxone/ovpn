#!/bin/sh
#
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 dreamboxone <https://t.me/routekernel1>
# Part of ovpn - https://github.com/dreamboxone/ovpn
#
# Shared helpers. Sourced, not executed.

OVPN_OWN_XRAY=/usr/libexec/ovpn/xray

# Which Xray to run.
#
# A router that already has a core - the xray-core package, which PassWall2
# and other front-ends pull in - should use it rather than a second copy of
# the same thing sitting in flash. So try what is already installed first and
# fall back to the copy this package carries.
#
# The choice is made by asking, not by comparing version numbers: with a
# configuration to hand, each candidate is offered it and the first one that
# accepts wins. An older core that cannot read a modern REALITY or xhttp
# stanza is exactly what a version check would wave through, and it would
# then fail at the only moment that matters.
find_xray() {
	_cfg="$1"
	for _x in /usr/bin/xray /usr/local/bin/xray "$OVPN_OWN_XRAY"; do
		[ -x "$_x" ] || continue
		if [ -n "$_cfg" ]; then
			"$_x" run -test -config "$_cfg" >/dev/null 2>&1 || continue
		else
			"$_x" version >/dev/null 2>&1 || continue
		fi
		echo "$_x"
		return 0
	done
	return 1
}
