#!/bin/bash
# networking-05 cleanup: delete labnet, labnet-old and every other
# profile created on the lab interface during the lab, then turn the
# automatic "Wired connection" profiles that setup.sh disabled back on.
LAB=networking-05
STATE_FILE=/opt/linux-labs/state/$LAB

nm_prop() { nmcli -g "$2" connection show uuid "$1" 2>/dev/null; }

# setup.sh disabled autoconnect with --temporary: modify an in-memory
# profile back, load a profile stored on disk again from its file.
restore_profile() {
	local uuid=$1 file
	nmcli connection modify --temporary uuid "$uuid" connection.autoconnect yes >/dev/null 2>&1 || true
	# The file appears only in the profile list
	file=$(nmcli -g UUID,FILENAME connection show 2>/dev/null | sed -n "s/^$uuid://p" | sed 's/\\:/:/g')
	case "$file" in
		"" | /run/*) ;;
		*) nmcli connection load "$file" >/dev/null 2>&1 || true ;;
	esac
}

iface=""
known=""
saved=""
if [ -r "$STATE_FILE" ]; then
	iface=$(sed -n 1p "$STATE_FILE")
	known=$(sed -n 's/^known=//p' "$STATE_FILE" | tr '\n' ' ')
	saved=$(sed -n 's/^saved=//p' "$STATE_FILE" | tr '\n' ' ')
fi

if command -v nmcli >/dev/null 2>&1 && systemctl is-active --quiet NetworkManager; then
	mac=""
	[ -z "$iface" ] || mac=$(tr 'A-F' 'a-f' < "/sys/class/net/$iface/address" 2>/dev/null)
	for u in $(nmcli -g UUID connection show 2>/dev/null); do
		case " $known " in
			*" $u "*) continue ;;
		esac
		del=0
		case "$(nm_prop "$u" connection.id)" in
			labnet | labnet-old) del=1 ;;
		esac
		if [ -n "$iface" ]; then
			case "$(nm_prop "$u" connection.interface-name)" in
				"$iface" | "${iface}0") del=1 ;;
			esac
			[ "$(nm_prop "$u" GENERAL.DEVICES)" = "$iface" ] && del=1
			if [ -n "$mac" ] && [ "$(nm_prop "$u" 802-3-ethernet.mac-address | tr 'A-F' 'a-f')" = "$mac" ]; then
				del=1
			fi
		fi
		[ "$del" = 0 ] || nmcli connection delete uuid "$u" >/dev/null 2>&1
	done

	# Addresses added by hand with ip stay on the interface without a
	# profile; remove them before the automatic profiles return
	if [ -n "$iface" ] && [ -e "/sys/class/net/$iface" ]; then
		ip -4 addr flush dev "$iface" scope global >/dev/null 2>&1
		ip -6 addr flush dev "$iface" scope global >/dev/null 2>&1
	fi

	for u in $saved; do
		restore_profile "$u"
		nmcli --wait 0 connection up uuid "$u" </dev/null >/dev/null 2>&1 || true
	done
fi

rm -f "$STATE_FILE"
exit 0
