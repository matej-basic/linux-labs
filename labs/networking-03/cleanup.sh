#!/bin/bash
# networking-03 cleanup: remove bond0 and its port profiles, restore the
# automatic "Wired connection" profiles that setup.sh deleted.
LAB=networking-03
STATE_FILE=/opt/linux-labs/state/$LAB

nm_prop() { nmcli -g "$2" connection show uuid "$1" 2>/dev/null; }

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

# Restore the automatic profiles recorded by setup.sh
if [ -r "$STATE_FILE" ] && command -v nmcli >/dev/null 2>&1; then
	while IFS= read -r line; do
		case "$line" in
			restore=*)
				entry="${line#restore=}"
				iface="${entry%%|*}"
				name="${entry#*|}"
				if ! nmcli -g connection.id connection show id "$name" >/dev/null 2>&1; then
					nmcli connection add type ethernet con-name "$name" ifname "$iface" >/dev/null 2>&1
				fi
				;;
			port1=* | port2=*)
				ip link set "${line#*=}" up >/dev/null 2>&1
				;;
		esac
	done < "$STATE_FILE"
fi

rm -f "$STATE_FILE"
exit 0
