#!/bin/bash
# networking-02 cleanup: remove vlan10, restore the original hostname and
# the NIC's automatic connection profiles, remove the /etc/hosts entry.
STATE_FILE=/opt/linux-labs/state/networking-02

orig_host=""
have_state=0
if [ -r "$STATE_FILE" ]; then
	have_state=1
	orig_host=$(sed -n 2p "$STATE_FILE")
fi

# setup.sh disabled autoconnect with --temporary: modify an in-memory
# profile back, load a profile stored on disk again from its file.
restore_profile() {
	local uuid=$1 file
	nmcli connection modify --temporary uuid "$uuid" connection.autoconnect yes >/dev/null 2>&1 || true
	file=$(nmcli -g UUID,FILENAME connection show 2>/dev/null | sed -n "s/^$uuid://p" | sed 's/\\:/:/g')
	case "$file" in
	"" | /run/*) ;;
	*) nmcli connection load "$file" >/dev/null 2>&1 || true ;;
	esac
}

# Delete every connection profile of the interface vlan10
if command -v nmcli >/dev/null 2>&1; then
	while IFS=: read -r uuid type; do
		[ -n "$uuid" ] || continue
		[ "$type" = vlan ] || continue
		iface=$(nmcli -g connection.interface-name connection show uuid "$uuid" 2>/dev/null || true)
		[ "$iface" = vlan10 ] && nmcli connection delete uuid "$uuid" >/dev/null 2>&1
	done < <(nmcli -t -f UUID,TYPE connection show 2>/dev/null)
	nmcli connection delete vlan10 >/dev/null 2>&1 || true
fi
ip link delete vlan10 >/dev/null 2>&1 || true

# Turn the automatic profiles of the NIC back on
if [ "$have_state" = 1 ] && command -v nmcli >/dev/null 2>&1; then
	tail -n +3 "$STATE_FILE" | while read -r uuid; do
		[ -n "$uuid" ] || continue
		restore_profile "$uuid"
		nmcli --wait 0 connection up uuid "$uuid" >/dev/null 2>&1 || true
	done
fi

# Restore the hostname and drop the name entry
sed -i '/labhost\.example\.com/d' /etc/hosts 2>/dev/null || true
if [ "$have_state" = 1 ]; then
	hostnamectl set-hostname "$orig_host" >/dev/null 2>&1 || true
elif [ "$(hostnamectl --static 2>/dev/null)" = labhost ]; then
	hostnamectl set-hostname "" >/dev/null 2>&1 || true
fi

rm -f "$STATE_FILE"
exit 0
