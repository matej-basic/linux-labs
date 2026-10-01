#!/bin/bash
# networking-02 setup: pick a free NIC, remove its automatic NetworkManager
# profile, and remember the original hostname and profile name so that
# cleanup.sh can restore them. Prints nothing on success.
set -eu

LAB=networking-02
STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/$LAB"

die() {
	echo "Error: $*" >&2
	exit 1
}

command -v nmcli >/dev/null 2>&1 || die "nmcli is not installed"
systemctl is-active --quiet NetworkManager || die "NetworkManager is not running"

# Interfaces that carry a default route (IPv4 or IPv6)
default_ifs=$( { ip -4 route show default; ip -6 route show default; } 2>/dev/null |
	awk '{ for (i = 1; i < NF; i++) if ($i == "dev") print $(i + 1) }' | sort -u)

# First free NIC: physical ethernet, not the default-route interface,
# not wireless, not enslaved to a bridge, bond or team.
nic=""
for d in /sys/class/net/*; do
	n=${d##*/}
	[ -e "$d/device" ] || continue
	[ "$(cat "$d/type" 2>/dev/null)" = 1 ] || continue
	[ -d "$d/wireless" ] && continue
	[ -e "$d/master" ] && continue
	printf '%s\n' "$default_ifs" | grep -qx "$n" && continue
	nic=$n
	break
done
[ -n "$nic" ] || die "no free ethernet interface found (a NIC other than the default-route interface is required). The lab was not started."

# Original hostname and profile name: keep the values from an earlier run
# so that a second setup does not record the lab's own changes.
if [ -r "$STATE_FILE" ]; then
	orig_host=$(sed -n 2p "$STATE_FILE")
	orig_profile=$(sed -n 3p "$STATE_FILE")
else
	orig_host=$(hostnamectl --static 2>/dev/null || true)
	if [ "$orig_host" = labhost ]; then
		die "the hostname is already labhost; set another hostname first"
	fi
	orig_profile=""
fi

# Remove vlan10 and the automatic profile(s) on the free NIC
while IFS=: read -r uuid type; do
	[ -n "$uuid" ] || continue
	iface=$(nmcli -g connection.interface-name connection show uuid "$uuid" 2>/dev/null || true)
	case "$type" in
		vlan)
			[ "$iface" = vlan10 ] && nmcli connection delete uuid "$uuid" >/dev/null 2>&1
			;;
		802-3-ethernet)
			if [ "$iface" = "$nic" ]; then
				name=$(nmcli -g connection.id connection show uuid "$uuid" 2>/dev/null || true)
				[ -n "$orig_profile" ] || orig_profile=$name
				nmcli connection delete uuid "$uuid" >/dev/null 2>&1
			fi
			;;
	esac
done < <(nmcli -t -f UUID,TYPE connection show 2>/dev/null)
ip link delete vlan10 >/dev/null 2>&1 || true

# Start without the lab's hostname and name entry
sed -i '/labhost\.example\.com/d' /etc/hosts
if [ "$(hostnamectl --static 2>/dev/null || true)" = labhost ]; then
	hostnamectl set-hostname "$orig_host"
fi

mkdir -p "$STATE_DIR"
printf '%s\n%s\n%s\n' "$nic" "$orig_host" "$orig_profile" > "$STATE_FILE"
chmod 644 "$STATE_FILE"
