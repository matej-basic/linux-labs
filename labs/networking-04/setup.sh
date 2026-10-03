#!/bin/bash
# networking-04 setup: pick the first free NIC, take its automatic
# "Wired connection" profiles out of the way and record the interface,
# the default-route interface and the existing profiles for the grader
# and cleanup.sh. Prints nothing on success.
set -eu

LAB=networking-04
STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/$LAB"

die() {
	echo "$LAB: $*" >&2
	exit 1
}

command -v nmcli >/dev/null 2>&1 || die "nmcli is not installed"
systemctl is-active --quiet NetworkManager || die "NetworkManager is not running"
[ -d /proc/sys/net/ipv6 ] || die "IPv6 is disabled in the kernel, the lab needs it"

# Start from a clean state: removes the profiles of an earlier run and
# restores the profiles it disabled
bash "$(dirname "$0")/cleanup.sh"

defifs=$(ip route show default 2>/dev/null | awk '{ for (i = 1; i < NF; i++) if ($i == "dev") print $(i + 1) }' | sort -u | tr '\n' ' ')
defif="${defifs%% *}"
[ -n "$defif" ] || die "no default route found, cannot tell which interface to keep"

# First free interface in name order: physical Ethernet, not a
# default-route interface, not enslaved, no global IPv4 address
iface=""
for d in /sys/class/net/*; do
	n="${d##*/}"
	[ -e "$d/device" ] || continue
	[ "$(cat "$d/type" 2>/dev/null)" = 1 ] || continue
	if [ -e "$d/master" ]; then continue; fi
	case " $defifs " in
		*" $n "*) continue ;;
	esac
	[ -z "$(ip -4 -o addr show dev "$n" scope global 2>/dev/null)" ] || continue
	iface="$n"
	break
done
[ -n "$iface" ] || die "no free Ethernet interface found"
[ -d "/proc/sys/net/ipv6/conf/$iface" ] || die "IPv6 is not available on $iface"

# Ethernet profiles bound to the interface by name or by MAC address
profile_on_iface() {
	local uuid="$1" ifn mac
	ifn=$(nmcli -g connection.interface-name connection show uuid "$uuid" 2>/dev/null) || return 1
	[ "$ifn" = "$iface" ] && return 0
	[ -z "$ifn" ] || return 1
	mac=$(nmcli -g 802-3-ethernet.mac-address connection show uuid "$uuid" 2>/dev/null | tr 'A-F' 'a-f')
	[ -n "$mac" ] && [ "$mac" = "$(cat "/sys/class/net/$iface/address")" ]
}

all=$(nmcli -g UUID connection show 2>/dev/null)
saved=()
for uuid in $all; do
	[ "$(nmcli -g connection.type connection show uuid "$uuid" 2>/dev/null)" = 802-3-ethernet ] || continue
	[ -z "$(nmcli -g connection.slave-type connection show uuid "$uuid" 2>/dev/null)" ] || continue
	if profile_on_iface "$uuid"; then
		saved+=("$uuid")
	fi
done

# Line 1 is the interface for the student; the rest is for the scripts.
# known= lists every profile that existed before the lab, so cleanup.sh
# deletes only profiles created during the lab.
mkdir -p "$STATE_DIR"
{
	echo "$iface"
	echo "defif=$defif"
	for u in ${saved[@]+"${saved[@]}"}; do
		echo "saved=$u"
	done
	for u in $all; do
		echo "known=$u"
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
