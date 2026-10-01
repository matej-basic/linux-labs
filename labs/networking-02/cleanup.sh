#!/bin/bash
# networking-02 cleanup: remove vlan10, restore the original hostname and
# the NIC's original connection profile, remove the /etc/hosts entry.
STATE_FILE=/opt/linux-labs/state/networking-02

nic=""
orig_host=""
orig_profile=""
have_state=0
if [ -r "$STATE_FILE" ]; then
	have_state=1
	nic=$(sed -n 1p "$STATE_FILE")
	orig_host=$(sed -n 2p "$STATE_FILE")
	orig_profile=$(sed -n 3p "$STATE_FILE")
fi

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

# Restore the NIC's automatic profile if setup removed it and none exists
if [ -n "$nic" ] && [ -n "$orig_profile" ] && command -v nmcli >/dev/null 2>&1; then
	present=0
	while IFS=: read -r uuid type; do
		[ "$type" = 802-3-ethernet ] || continue
		iface=$(nmcli -g connection.interface-name connection show uuid "$uuid" 2>/dev/null || true)
		[ "$iface" = "$nic" ] && present=1
	done < <(nmcli -t -f UUID,TYPE connection show 2>/dev/null)
	if [ "$present" = 0 ]; then
		nmcli connection add type ethernet con-name "$orig_profile" ifname "$nic" >/dev/null 2>&1 || true
	fi
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
