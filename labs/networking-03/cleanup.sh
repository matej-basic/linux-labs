#!/bin/bash
# networking-03 cleanup: remove bond0 and its port profiles, turn the
# automatic "Wired connection" profiles that setup.sh disabled back on.
LAB=networking-03
STATE_FILE=/opt/linux-labs/state/$LAB

nm_prop() { nmcli -g "$2" connection show uuid "$1" 2>/dev/null; }

# setup.sh disabled autoconnect with --temporary: modify an in-memory
# profile back, load a profile stored on disk again from its file.
restore_profile() {
	local uuid=$1 file
	nmcli connection modify --temporary uuid "$uuid" connection.autoconnect yes >/dev/null 2>&1 || true
	file=$(nmcli -g GENERAL.FILENAME connection show uuid "$uuid" 2>/dev/null || true)
	case "$file" in
		"" | /run/*) ;;
		*) nmcli connection load "$file" >/dev/null 2>&1 || true ;;
	esac
}

if command -v nmcli >/dev/null 2>&1 && systemctl is-active --quiet NetworkManager; then
	uuids=$(nmcli -g UUID connection show 2>/dev/null)

	# Profiles of the bond itself
	bonds=""
	for u in $uuids; do
		[ "$(nm_prop "$u" connection.type)" = bond ] || continue
		[ "$(nm_prop "$u" connection.interface-name)" = bond0 ] || continue
		bonds="$bonds $u"
	done

	# Port profiles (master is bond0 by name or by UUID), then the bond
	for u in $uuids; do
		[ "$(nm_prop "$u" connection.slave-type)" = bond ] || continue
		m=$(nm_prop "$u" connection.master)
		case " bond0 $bonds " in
			*" $m "*) nmcli connection delete uuid "$u" >/dev/null 2>&1 ;;
		esac
	done
	for u in $bonds; do
		nmcli connection delete uuid "$u" >/dev/null 2>&1
	done
fi

ip link delete bond0 >/dev/null 2>&1

# Bring the ports back up and restore the profiles recorded by setup.sh
if [ -r "$STATE_FILE" ] && command -v nmcli >/dev/null 2>&1; then
	while IFS= read -r line; do
		case "$line" in
			port1=* | port2=*)
				ip link set "${line#*=}" up >/dev/null 2>&1
				;;
		esac
	done < "$STATE_FILE"
	while IFS= read -r line; do
		case "$line" in
			saved=*)
				restore_profile "${line#saved=}"
				nmcli --wait 0 connection up uuid "${line#saved=}" </dev/null >/dev/null 2>&1 || true
				;;
		esac
	done < "$STATE_FILE"
	# Unload the bonding driver if it was not loaded before the lab and
	# no other bond uses it
	if grep -qx 'bonding_loaded=0' "$STATE_FILE" &&
		[ -z "$(cat /sys/class/net/bonding_masters 2>/dev/null)" ]; then
		modprobe -r bonding >/dev/null 2>&1 || true
	fi
fi

rm -f "$STATE_FILE"
exit 0
