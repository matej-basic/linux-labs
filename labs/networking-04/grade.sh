#!/bin/bash
# networking-04 grader
source /opt/linux-labs/lib/grading.sh

STATE_FILE=/opt/linux-labs/state/networking-04
CON=lab-v6
ADDR4=192.168.150.10/24
ADDR6=fd00:150::10/64
NET4=10.150.0.0/24
GW4=192.168.150.254
NET6=fd00:250::/64
GW6=fd00:150::fe

grade_begin networking-04
grade_require_state networking-04 "$STATE_FILE"
iface=$(sed -n 1p "$STATE_FILE")
defif=$(sed -n 's/^defif=//p' "$STATE_FILE")

# One value of the profile; nmcli -g escapes colons, undo that
con_get() {
	nmcli -g "$1" connection show id "$CON" 2>/dev/null | sed 's/\\:/:/g'
}
con_is() { [ "$(con_get "$1")" = "$2" ]; }

# The profile setting $1 (a comma separated list) contains $2
con_has() {
	con_get "$1" | tr ',' '\n' | sed 's/^ *//; s/ *$//' | grep -Fxq "$2"
}

# The profile setting $1 has a route to $2 through $3
con_has_route() {
	con_get "$1" | tr ',' '\n' | awk -v n="$2" -v g="$3" '
		$1 == n && $2 == g { found = 1 } END { exit !found }'
}

# The file of a profile appears only in the profile list, not in
# "connection show <id>"
saved_to_disk() {
	local u f
	u=$(con_get connection.uuid)
	[ -n "$u" ] || return 1
	f=$(nmcli -g UUID,FILENAME connection show 2>/dev/null | sed -n "s/^$u://p")
	case "$f" in
		"" | /run/*) return 1 ;;
	esac
}

no_gateway() {
	[ -z "$(con_get ipv4.gateway)" ] && [ -z "$(con_get ipv6.gateway)" ]
}

active_on_iface() {
	con_is GENERAL.STATE activated && con_is GENERAL.DEVICES "$iface"
}

has_addr4() {
	ip -4 -o addr show dev "$iface" 2>/dev/null | awk -v a="$ADDR4" '$4 == a { found = 1 } END { exit !found }'
}

# Global, usable address: not tentative and not dadfailed
has_addr6() {
	ip -6 -o addr show dev "$iface" scope global 2>/dev/null |
		awk -v a="$ADDR6" '$4 == a && !/tentative|dadfailed/ { found = 1 } END { exit !found }'
}

# Kernel route to $2 via $3 on the lab interface, family $1
kernel_route() {
	ip "$1" -o route show to exact "$2" dev "$iface" 2>/dev/null |
		awk -v g="$3" '{ for (i = 1; i < NF; i++) if ($i == "via" && $(i + 1) == g) found = 1 } END { exit !found }'
}

no_default_on_iface() {
	[ -z "$(ip -4 route show default dev "$iface" 2>/dev/null)" ] &&
		[ -z "$(ip -6 route show default dev "$iface" 2>/dev/null)" ]
}

default_route_kept() {
	ip -4 route show default 2>/dev/null | awk -v d="$defif" '{ for (i = 1; i < NF; i++) if ($i == "dev" && $(i + 1) == d) found = 1 } END { exit !found }'
}

criterion "Connection $CON exists" nmcli connection show id "$CON"
criterion "Connection $CON is bound to interface $iface" con_is connection.interface-name "$iface"
criterion "Connection $CON is saved to disk" saved_to_disk
criterion "Connection $CON connects automatically" con_is connection.autoconnect yes
criterion "Connection $CON uses the manual IPv4 method" con_is ipv4.method manual
criterion "Connection $CON has the address $ADDR4" con_has ipv4.addresses "$ADDR4"
criterion "Connection $CON uses the manual IPv6 method" con_is ipv6.method manual
criterion "Connection $CON has the address $ADDR6" con_has ipv6.addresses "$ADDR6"
criterion "Connection $CON defines no gateway" no_gateway
criterion "$CON has the route $NET4 via $GW4" con_has_route ipv4.routes "$NET4" "$GW4"
criterion "$CON has the route $NET6 via $GW6" con_has_route ipv6.routes "$NET6" "$GW6"
criterion "Connection $CON is active on $iface" active_on_iface
criterion "Interface $iface has the address $ADDR4" has_addr4
criterion "Interface $iface has the usable address $ADDR6" has_addr6
criterion "The kernel routes $NET4 via $GW4 on $iface" kernel_route -4 "$NET4" "$GW4"
criterion "The kernel routes $NET6 via $GW6 on $iface" kernel_route -6 "$NET6" "$GW6"
criterion "No default route uses interface $iface" no_default_on_iface
criterion "The default route still uses $defif" default_route_kept
grade_end
