#!/bin/bash
# networking-03 grader
source /opt/linux-labs/lib/grading.sh

STATE_FILE=/opt/linux-labs/state/networking-03
BOND=bond0
ADDR=192.168.100.1/24
SYS=/sys/class/net/$BOND/bonding

grade_begin networking-03
grade_require_state networking-03 "$STATE_FILE"
port1=$(sed -n 's/^port1=//p' "$STATE_FILE")
port2=$(sed -n 's/^port2=//p' "$STATE_FILE")
defif=$(sed -n 's/^defif=//p' "$STATE_FILE")

nm_prop() { nmcli -g "$2" connection show uuid "$1" 2>/dev/null; }

# Comma list of a property without spaces, wrapped in commas
nm_list() { printf ',%s,' "$(nm_prop "$1" "$2" | tr -d ' ')"; }

UUIDS=$(nmcli -g UUID connection show 2>/dev/null)

# UUID of the bond profile for interface bond0
BOND_UUID=""
for u in $UUIDS; do
	[ "$(nm_prop "$u" connection.type)" = bond ] || continue
	[ "$(nm_prop "$u" connection.interface-name)" = "$BOND" ] || continue
	BOND_UUID="$u"
	break
done

# UUID of the saved port profile of interface $1 (master is bond0)
port_uuid() {
	local u m
	for u in $UUIDS; do
		[ "$(nm_prop "$u" connection.slave-type)" = bond ] || continue
		[ "$(nm_prop "$u" connection.interface-name)" = "$1" ] || continue
		m=$(nm_prop "$u" connection.master)
		if [ "$m" = "$BOND" ] || { [ -n "$BOND_UUID" ] && [ "$m" = "$BOND_UUID" ]; }; then
			echo "$u"
			return 0
		fi
	done
	return 1
}

bond_profile_exists() {
	[ -n "$BOND_UUID" ]
}

mode_active_backup() {
	[ -n "$BOND_UUID" ] || return 1
	case "$(nm_list "$BOND_UUID" bond.options)" in
		*,mode=active-backup,* | *,mode=1,*) ;;
		*) return 1 ;;
	esac
	[ "$(cut -d' ' -f1 "$SYS/mode" 2>/dev/null)" = active-backup ]
}

miimon_100() {
	[ -n "$BOND_UUID" ] || return 1
	case "$(nm_list "$BOND_UUID" bond.options)" in
		*,miimon=100,*) ;;
		*) return 1 ;;
	esac
	[ "$(cat "$SYS/miimon" 2>/dev/null)" = 100 ]
}

static_address() {
	[ -n "$BOND_UUID" ] || return 1
	[ "$(nm_prop "$BOND_UUID" ipv4.method)" = manual ] || return 1
	case "$(nm_list "$BOND_UUID" ipv4.addresses)" in
		*,"$ADDR",*) ;;
		*) return 1 ;;
	esac
	ip -4 -o addr show dev "$BOND" 2>/dev/null | awk -v a="$ADDR" '$4 == a { found = 1 } END { exit !found }'
}

ports_enslaved() {
	local slaves p
	slaves=" $(cat "$SYS/slaves" 2>/dev/null) "
	for p in "$port1" "$port2"; do
		case "$slaves" in
			*" $p "*) ;;
			*) return 1 ;;
		esac
	done
}

port_profiles_saved() {
	port_uuid "$port1" >/dev/null && port_uuid "$port2" >/dev/null
}

autoconnect_all() {
	local u
	[ -n "$BOND_UUID" ] || return 1
	for u in "$BOND_UUID" "$(port_uuid "$port1")" "$(port_uuid "$port2")"; do
		[ -n "$u" ] || return 1
		[ "$(nm_prop "$u" connection.autoconnect)" = yes ] || return 1
	done
}

has_active_port() {
	[ -n "$(cat "$SYS/active_slave" 2>/dev/null)" ]
}

default_route_kept() {
	ip route show default 2>/dev/null | awk -v d="$defif" '{ for (i = 1; i < NF; i++) if ($i == "dev" && $(i + 1) == d) found = 1 } END { exit !found }'
}

criterion "NetworkManager has a bond profile for bond0" bond_profile_exists
criterion "bond0 uses the mode active-backup" mode_active_backup
criterion "bond0 checks link state every 100 ms" miimon_100
criterion "bond0 has the static address $ADDR" static_address
criterion "$port1 and $port2 are ports of bond0" ports_enslaved
criterion "Saved port profiles exist for $port1 and $port2" port_profiles_saved
criterion "bond0 and both port profiles connect automatically" autoconnect_all
criterion "bond0 has an active port" has_active_port
criterion "The default route still uses $defif" default_route_kept
grade_end
