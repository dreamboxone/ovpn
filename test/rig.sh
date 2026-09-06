#!/bin/sh
#
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 dreamboxone <https://t.me/routekernel1>
# Part of ovpn - https://github.com/dreamboxone/ovpn
#
# rig.sh - stand the router's scripts up somewhere that is not a router.
#
# Sourced by the tests. It lays the real scripts out in a throwaway tree,
# points every root at it, and puts a stand-in `uci` on the path so that
# settings can be varied without a router to vary them on.
#
# The point is that the tests exercise the shipped scripts themselves. A test
# that reimplements what it is testing proves only that two things agree.

RIG_SRC="$(cd "$(dirname "$0")/.." && pwd)"
RIG="${RIG_ROOT:-${TMPDIR:-/tmp}/ovpn-rig}"

rig_setup() {
	rm -rf "$RIG"
	mkdir -p "$RIG/lib" "$RIG/etc" "$RIG/run" "$RIG/bin" "$RIG/core" "$RIG/var/etc"

	for f in "$RIG_SRC"/package/ovpn/files/ovpn-*; do
		cp "$f" "$RIG/lib/$(basename "$f")"
	done
	chmod +x "$RIG"/lib/* 2>/dev/null || true

	: > "$RIG/uci.conf"

	cat > "$RIG/bin/uci" <<'UCI'
#!/bin/sh
# Stand-in for uci. Understands exactly what these scripts ask of it.
_get=""; _key=""
for a in "$@"; do
	case "$a" in
		get) _get=1 ;;
		ovpn.config.*) _key="${a#ovpn.config.}" ;;
	esac
done
if [ -n "$_get" ] && [ -n "$_key" ]; then
	sed -n "s/^$_key=//p" "${OVPN_TEST_UCI:-/dev/null}" 2>/dev/null | head -1
fi
exit 0
UCI
	chmod +x "$RIG/bin/uci"

	# A core the scripts can find and run. On a machine where the real binary
	# has a different name or extension, this is what bridges the gap.
	if [ -n "$RIG_XRAY" ] && [ -x "$RIG_XRAY" ]; then
		printf '#!/bin/sh\nexec "%s" "$@"\n' "$RIG_XRAY" > "$RIG/core/xray"
		chmod +x "$RIG/core/xray"
	fi

	OVPN_LIB="$RIG/lib"
	OVPN_ETC="$RIG/etc"
	OVPN_RUN="$RIG/run"
	OVPN_OWN_DIR="$RIG/core"
	OVPN_CONFIG_JSON="$RIG/var/etc/ovpn.json"
	OVPN_TEST_UCI="$RIG/uci.conf"
	PATH="$RIG/bin:$PATH"
	export OVPN_LIB OVPN_ETC OVPN_RUN OVPN_OWN_DIR OVPN_CONFIG_JSON OVPN_TEST_UCI PATH
}

# rig_set key value
rig_set() {
	sed -i "/^$1=/d" "$RIG/uci.conf" 2>/dev/null || true
	printf '%s=%s\n' "$1" "$2" >> "$RIG/uci.conf"
}

rig_clear() { : > "$RIG/uci.conf"; }

PASS=0
FAIL=0

ok()   { PASS=$((PASS + 1)); echo "  ok   - $1"; }
bad()  { FAIL=$((FAIL + 1)); echo "  FAIL - $1"; }
check() { if [ "$1" = "$2" ]; then ok "$3"; else bad "$3 (expected [$2], got [$1])"; fi; }

rig_report() {
	echo
	echo "$PASS passed, $FAIL failed"
	[ "$FAIL" -eq 0 ]
}
