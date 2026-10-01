#!/bin/bash
# firewall-02 setup: firewalld running, no lab rich rule, the first free
# Ethernet interface out of the trusted zone. The interface name goes to
# the state file. Prints nothing on success.
set -eu

LAB=firewall-02
STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/$LAB"
RULE='rule family="ipv4" source address="192.168.1.0/24" port port="443" protocol="tcp" accept'

# First Ethernet interface that is not the default-route interface, not
# enslaved and not virtual.
default_if=$(ip route show default 2>/dev/null |
	awk '{ for (i = 1; i < NF; i++) if ($i == "dev") { print $(i + 1); exit } }')
iface=
for p in /sys/class/net/*; do
	n=${p##*/}
	[ "$n" = lo ] && continue
	[ "$n" = "${default_if:-}" ] && continue
	[ -e "$p/device" ] || continue
	[ -d "$p/wireless" ] && continue
	[ -e "$p/master" ] && continue
	[ "$(cat "$p/type" 2>/dev/null)" = 1 ] || continue
	iface=$n
	break
done
if [ -z "$iface" ]; then
	echo "Error: $LAB needs a free Ethernet interface (not the one with the default route) and found none." >&2
	exit 1
fi

# firewalld must be installed and running
if ! command -v firewall-cmd >/dev/null 2>&1; then
	dnf -y install firewalld >/dev/null 2>&1 || {
		echo "Error: could not install firewalld." >&2
		exit 1
	}
fi
systemctl enable --now firewalld >/dev/null 2>&1 || {
	echo "Error: could not start firewalld." >&2
	exit 1
}
for _ in $(seq 1 20); do
	firewall-cmd --state >/dev/null 2>&1 && break
	sleep 1
done
firewall-cmd --state >/dev/null 2>&1 || {
	echo "Error: firewalld is not responding." >&2
	exit 1
}

# Reset: remove the lab rule and take the interface out of trusted
firewall-cmd --permanent --zone=public --remove-rich-rule="$RULE" >/dev/null 2>&1 || true
firewall-cmd --permanent --zone=trusted --remove-interface="$iface" >/dev/null 2>&1 || true
nmcli -g NAME connection show 2>/dev/null | while IFS= read -r name; do
	[ "$(nmcli -g connection.interface-name connection show "$name" 2>/dev/null)" = "$iface" ] || continue
	[ "$(nmcli -g connection.zone connection show "$name" 2>/dev/null)" = trusted ] || continue
	nmcli connection modify "$name" connection.zone "" >/dev/null 2>&1 || true
done
firewall-cmd --reload >/dev/null 2>&1 || true
firewall-cmd --zone=public --remove-rich-rule="$RULE" >/dev/null 2>&1 || true
if [ "$(firewall-cmd --get-zone-of-interface="$iface" 2>/dev/null)" = trusted ]; then
	firewall-cmd --zone="$(firewall-cmd --get-default-zone)" --change-interface="$iface" >/dev/null 2>&1 || true
fi

# Record the interface for the grader (readable by unprivileged users)
mkdir -p "$STATE_DIR"
echo "$iface" > "$STATE_FILE"
chmod 644 "$STATE_FILE"
