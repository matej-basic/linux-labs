#!/bin/bash
# networking-03 setup: pick the two free NICs, take their automatic
# "Wired connection" profiles out of the way and record everything for
# the grader and cleanup.sh. Prints nothing on success.
set -eu

LAB=networking-03
STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/$LAB"

die() {
	echo "$LAB: $*" >&2
	exit 1
}

command -v nmcli >/dev/null 2>&1 || die "nmcli is not installed"
systemctl is-active --quiet NetworkManager || die "NetworkManager is not running"

# Start from a clean state: removes bond0 and its ports, restores the
# profiles disabled by an earlier run
bash "$(dirname "$0")/cleanup.sh"

# Interfaces that carry a default route are never used
defifs=$(ip route show default 2>/dev/null | awk '{ for (i = 1; i < NF; i++) if ($i == "dev") print $(i + 1) }' | sort -u | tr '\n' ' ')
defif="${defifs%% *}"
[ -n "$defif" ] || die "no default route found, cannot tell which interface to keep"

# Free interfaces: physical Ethernet, not default-route, not enslaved,
# no global IPv4 address (an interface with an address is in use)
free=()
for d in /sys/class/net/*; do
	n="${d##*/}"
	[ -e "$d/device" ] || continue
	[ "$(cat "$d/type" 2>/dev/null)" = 1 ] || continue
	if [ -e "$d/master" ]; then continue; fi
	case " $defifs " in
		*" $n "*) continue ;;
	esac
	[ -z "$(ip -4 -o addr show dev "$n" scope global 2>/dev/null)" ] || continue
	free+=("$n")
done
[ "${#free[@]}" -ge 2 ] || die "need two free network interfaces, found ${#free[@]}"
port1="${free[0]}"
port2="${free[1]}"

# Ethernet profiles bound to an interface by name or by MAC address
profile_on_iface() {
	local uuid="$1" iface="$2" ifn mac
	ifn=$(nmcli -g connection.interface-name connection show uuid "$uuid" 2>/dev/null) || return 1
	[ "$ifn" = "$iface" ] && return 0
	[ -z "$ifn" ] || return 1
	mac=$(nmcli -g 802-3-ethernet.mac-address connection show uuid "$uuid" 2>/dev/null | tr 'A-F' 'a-f')
	[ -n "$mac" ] && [ "$mac" = "$(cat "/sys/class/net/$iface/address")" ]
}

saved=()
for uuid in $(nmcli -g UUID connection show 2>/dev/null); do
	[ "$(nmcli -g connection.type connection show uuid "$uuid" 2>/dev/null)" = 802-3-ethernet ] || continue
	[ -z "$(nmcli -g connection.slave-type connection show uuid "$uuid" 2>/dev/null)" ] || continue
	if profile_on_iface "$uuid" "$port1" || profile_on_iface "$uuid" "$port2"; then
		saved+=("$uuid")
	fi
done

# Record the state before changing anything
bonding_loaded=0
[ ! -d /sys/module/bonding ] || bonding_loaded=1
mkdir -p "$STATE_DIR"
{
	echo "bonding_loaded=$bonding_loaded"
	echo "port1=$port1"
	echo "port2=$port2"
	echo "defif=$defif"
	for u in ${saved[@]+"${saved[@]}"}; do
		echo "saved=$u"
	done
} > "$STATE_FILE"
chmod 644 "$STATE_FILE"

# Take the profiles out of the way without deleting them. --temporary
# keeps the change in memory, so NetworkManager's automatic profiles are
# not written to disk; cleanup.sh turns autoconnect back on.
for u in ${saved[@]+"${saved[@]}"}; do
	nmcli connection modify --temporary uuid "$u" connection.autoconnect no
	nmcli connection down uuid "$u" >/dev/null 2>&1 || true
done
