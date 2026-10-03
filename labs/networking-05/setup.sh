#!/bin/bash
# networking-05 setup: pick the first free NIC, take its automatic
# "Wired connection" profiles out of the way, record the interface and
# the default-route profile, then create the broken profile labnet and
# the competing profile labnet-old. Prints nothing on success.
set -eu

LAB=networking-05
STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/$LAB"

die() {
	echo "$LAB: $*" >&2
	exit 1
}

command -v nmcli >/dev/null 2>&1 || die "nmcli is not installed"
systemctl is-active --quiet NetworkManager || die "NetworkManager is not running"

# Start from a clean state: removes the profiles of an earlier run and
# restores the profiles it disabled
bash "$(dirname "$0")/cleanup.sh"

defifs=$(ip route show default 2>/dev/null | awk '{ for (i = 1; i < NF; i++) if ($i == "dev") print $(i + 1) }' | sort -u | tr '\n' ' ')
defif="${defifs%% *}"
[ -n "$defif" ] || die "no default route found, cannot tell which interface to keep"

# The profile that carries the default route, and the settings the
# grader compares at the end
defuuid=$(nmcli -g UUID,DEVICE connection show --active 2>/dev/null | awk -F: -v d="$defif" '$2 == d { print $1; exit }')
[ -n "$defuuid" ] || die "no active NetworkManager profile on $defif"
DEF_FIELDS=connection.id,connection.interface-name,connection.autoconnect,ipv4.method,ipv4.addresses,ipv4.gateway,ipv4.never-default,ipv4.routes
defsum=$(nmcli -g "$DEF_FIELDS" connection show uuid "$defuuid" | md5sum | cut -d' ' -f1)

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
	echo "defuuid=$defuuid"
	echo "defsum=$defsum"
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

# The broken profile: bound to an interface name that does not exist,
# DHCP on a network without a DHCP server, no autoconnect
nmcli connection add type ethernet con-name labnet ifname "${iface}0" \
	autoconnect no ipv4.method auto ipv4.addresses 192.168.50.10/24 \
	>/dev/null ||
	die "cannot create the profile labnet"

# An older profile for the same interface with a wrong address that
# wins every automatic activation
nmcli connection add type ethernet con-name labnet-old ifname "$iface" \
	autoconnect yes connection.autoconnect-priority 10 \
	ipv4.method manual ipv4.addresses 192.168.5.10/24 >/dev/null ||
	die "cannot create the profile labnet-old"
nmcli --wait 20 connection up labnet-old >/dev/null 2>&1 ||
	die "cannot activate the profile labnet-old on $iface"
