#!/bin/bash
# networking-01 setup: pick the first free ethernet interface, remember
# it, and take its automatic NetworkManager profiles out of the way.
# Prints nothing on success.
set -eu

STATE_FILE=/opt/linux-labs/state/networking-01

# Re-enable autoconnect on a profile that a run of this setup disabled.
# The change was made with --temporary, so a profile stored on disk is
# loaded again from its file; an in-memory one is modified back.
restore_profile() {
	local uuid=$1 file
	nmcli connection modify --temporary uuid "$uuid" connection.autoconnect yes &>/dev/null || true
	file=$(nmcli -g UUID,FILENAME connection show 2>/dev/null | sed -n "s/^$uuid://p" | sed 's/\\:/:/g')
	case "$file" in
	"" | /run/*) ;;
	*) nmcli connection load "$file" &>/dev/null || true ;;
	esac
}

# Restore profiles disabled by an earlier run, so a rerun starts clean
restore_saved() {
	local uuid
	[ -r "$STATE_FILE" ] || return 0
	tail -n +3 "$STATE_FILE" | while read -r uuid; do
		[ -n "$uuid" ] || continue
		restore_profile "$uuid"
	done
}

if ! command -v nmcli &>/dev/null || ! systemctl is-active --quiet NetworkManager; then
	echo "networking-01: NetworkManager is not running." >&2
	exit 1
fi

nmcli connection delete labnet-static &>/dev/null || true
restore_saved

orig=$(ip -o route show default | awk '{ for (i = 1; i < NF; i++) if ($i == "dev") { print $(i + 1); exit } }')
if [ -z "$orig" ]; then
	echo "networking-01: no default route found; cannot tell which interface is in use." >&2
	exit 1
fi

# Free interface: physical ethernet, not the default-route interface,
# not enslaved to a bond, bridge or team.
iface=""
for path in /sys/class/net/*; do
	dev=${path##*/}
	[ "$dev" = "$orig" ] && continue
	[ "$(cat "$path/type" 2>/dev/null)" = 1 ] || continue
	[ -e "$path/device" ] || continue
	[ -e "$path/master" ] && continue
	iface=$dev
	break
done
if [ -z "$iface" ]; then
	echo "networking-01: no free ethernet interface (all others carry the default route or are in use)." >&2
	exit 1
fi

# Take the automatic profiles bound to the free interface out of the way.
# --temporary keeps the change in memory: NetworkManager's automatic
# "Wired connection N" profiles are not written to disk.
saved=()
while read -r uuid; do
	[ -n "$uuid" ] || continue
	bound=$(nmcli -g connection.interface-name connection show uuid "$uuid" 2>/dev/null || true)
	if [ "$bound" = "$iface" ]; then
		saved+=("$uuid")
		nmcli connection modify --temporary uuid "$uuid" connection.autoconnect no
		nmcli connection down uuid "$uuid" &>/dev/null || true
	fi
done < <(nmcli -g UUID connection show)

mkdir -p "$(dirname "$STATE_FILE")"
{
	echo "$iface"
	echo "$orig"
	[ "${#saved[@]}" -eq 0 ] || printf '%s\n' "${saved[@]}"
} > "$STATE_FILE"
chmod 644 "$STATE_FILE"
