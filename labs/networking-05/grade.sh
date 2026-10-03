#!/bin/bash
# networking-05 grader
source /opt/linux-labs/lib/grading.sh

STATE_FILE=/opt/linux-labs/state/networking-05
CON=labnet
ADDR4=192.168.50.10/24
DEF_FIELDS=connection.id,connection.interface-name,connection.autoconnect,ipv4.method,ipv4.addresses,ipv4.gateway,ipv4.never-default,ipv4.routes

grade_begin networking-05
grade_require_state networking-05 "$STATE_FILE"
iface=$(sed -n 1p "$STATE_FILE")
defif=$(sed -n 's/^defif=//p' "$STATE_FILE")
defuuid=$(sed -n 's/^defuuid=//p' "$STATE_FILE")
defsum=$(sed -n 's/^defsum=//p' "$STATE_FILE")

# One value of the profile; nmcli -g escapes colons, undo that
con_get() {
	nmcli -g "$1" connection show id "$CON" 2>/dev/null | sed 's/\\:/:/g'
}
con_is() { [ "$(con_get "$1")" = "$2" ]; }

no_gateway() {
	nmcli connection show id "$CON" >/dev/null 2>&1 && con_is ipv4.gateway ""
}

active_on_iface() {
	con_is GENERAL.STATE activated && con_is GENERAL.DEVICES "$iface"
}

has_addr4() {
	ip -4 -o addr show dev "$iface" 2>/dev/null | awk -v a="$ADDR4" '$4 == a { found = 1 } END { exit !found }'
}

no_default_on_iface() {
	[ -z "$(ip -4 route show default dev "$iface" 2>/dev/null)" ] &&
		[ -z "$(ip -6 route show default dev "$iface" 2>/dev/null)" ]
}

# Any other Ethernet profile bound to the interface by name, or by MAC
# address without a name, that connects automatically
no_other_autoconnect() {
	local own u ifn mac ifmac
	own=$(con_get connection.uuid)
	ifmac=$(tr 'A-F' 'a-f' < "/sys/class/net/$iface/address" 2>/dev/null)
	for u in $(nmcli -g UUID connection show 2>/dev/null); do
		[ "$u" != "$own" ] || continue
		[ "$(nmcli -g connection.type connection show uuid "$u" 2>/dev/null)" = 802-3-ethernet ] || continue
		ifn=$(nmcli -g connection.interface-name connection show uuid "$u" 2>/dev/null)
		if [ "$ifn" != "$iface" ]; then
			[ -z "$ifn" ] || continue
			mac=$(nmcli -g 802-3-ethernet.mac-address connection show uuid "$u" 2>/dev/null | tr 'A-F' 'a-f')
			[ -n "$mac" ] && [ "$mac" = "$ifmac" ] || continue
		fi
		[ "$(nmcli -g connection.autoconnect connection show uuid "$u" 2>/dev/null)" = yes ] && return 1
	done
	return 0
}

default_route_kept() {
	ip -4 route show default 2>/dev/null | awk -v d="$defif" '{ for (i = 1; i < NF; i++) if ($i == "dev" && $(i + 1) == d) found = 1 } END { exit !found }'
}

# The profile active on the default-route interface is the one from
# the start of the lab, with the same key settings
default_profile_kept() {
	local u
	u=$(nmcli -g UUID,DEVICE connection show --active 2>/dev/null | awk -F: -v d="$defif" '$2 == d { print $1; exit }')
	[ -n "$u" ] && [ "$u" = "$defuuid" ] || return 1
	[ "$(nmcli -g "$DEF_FIELDS" connection show uuid "$u" | md5sum | cut -d' ' -f1)" = "$defsum" ]
}

criterion "Connection $CON exists" nmcli connection show id "$CON"
criterion "Connection $CON is bound to interface $iface" con_is connection.interface-name "$iface"
criterion "Connection $CON uses the manual IPv4 method" con_is ipv4.method manual
criterion "Connection $CON has only the address $ADDR4" con_is ipv4.addresses "$ADDR4"
criterion "Connection $CON defines no IPv4 gateway" no_gateway
criterion "Connection $CON connects automatically" con_is connection.autoconnect yes
criterion "Connection $CON is active on $iface" active_on_iface
criterion "Interface $iface has the address $ADDR4" has_addr4
criterion "No default route uses interface $iface" no_default_on_iface
criterion "No other profile for $iface connects automatically" no_other_autoconnect
criterion "The default route still uses $defif" default_route_kept
criterion "The profile of $defif is unchanged" default_profile_kept
grade_end
