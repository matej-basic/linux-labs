#!/bin/bash
# networking-02 setup: pick a free NIC, take its automatic NetworkManager
# profiles out of the way, and remember the original hostname and those
# profiles so that cleanup.sh can restore them. Prints nothing on success.
set -eu

LAB=networking-02
STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/$LAB"

die() {
	echo "Error: $*" >&2
	exit 1
}

# Re-enable autoconnect on a profile that a run of this setup disabled.
# The change was made with --temporary, so a profile stored on disk is
# loaded again from its file; an in-memory one is modified back.
restore_profile() {
	local uuid=$1 file
	nmcli connection modify --temporary uuid "$uuid" connection.autoconnect yes >/dev/null 2>&1 || true
	file=$(nmcli -g UUID,FILENAME connection show 2>/dev/null | sed -n "s/^$uuid://p" | sed 's/\\:/:/g')
	case "$file" in
	"" | /run/*) ;;
	*) nmcli connection load "$file" >/dev/null 2>&1 || true ;;
	esac
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

# Original hostname: keep the value from an earlier run so that a second
# setup does not record the lab's own change. Profiles disabled by an
# earlier run are restored first, so a rerun starts clean.
if [ -r "$STATE_FILE" ]; then
	orig_host=$(sed -n 2p "$STATE_FILE")
	tail -n +3 "$STATE_FILE" | while read -r uuid; do
		[ -n "$uuid" ] || continue
		restore_profile "$uuid"
	done
else
	orig_host=$(hostnamectl --static 2>/dev/null || true)
	if [ "$orig_host" = labhost ]; then
		die "the hostname is already labhost; set another hostname first"
	fi
fi

# Remove vlan10. Take the profiles bound to the free NIC out of the way
# without deleting them: --temporary keeps the change in memory, so
# NetworkManager's automatic "Wired connection N" profiles are not
# written to disk, and cleanup.sh turns autoconnect back on.
saved=()
while IFS=: read -r uuid type; do
	[ -n "$uuid" ] || continue
	iface=$(nmcli -g connection.interface-name connection show uuid "$uuid" 2>/dev/null || true)
	case "$type" in
		vlan)
			[ "$iface" = vlan10 ] && nmcli connection delete uuid "$uuid" >/dev/null 2>&1
			;;
		802-3-ethernet)
			if [ "$iface" = "$nic" ]; then
				saved+=("$uuid")
				nmcli connection modify --temporary uuid "$uuid" connection.autoconnect no
				nmcli connection down uuid "$uuid" >/dev/null 2>&1 || true
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
{
	printf '%s\n%s\n' "$nic" "$orig_host"
	[ "${#saved[@]}" -eq 0 ] || printf '%s\n' "${saved[@]}"
} > "$STATE_FILE"
chmod 644 "$STATE_FILE"
