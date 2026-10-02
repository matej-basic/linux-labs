#!/bin/bash
# firewall-02 setup: firewalld running, no lab rich rule, and the first
# free Ethernet interface on the lab connection fwlab, a profile without
# IP addressing in no zone. The automatic profiles on that interface are
# taken out of the way, because their DHCP retries on a network without
# a DHCP server keep moving the interface between firewalld zones.
# Prints nothing on success.
set -eu
source /opt/linux-labs/lib/packages.sh

LAB=firewall-02
CONN=fwlab
STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/$LAB"
BACKUP="$STATE_DIR/$LAB.firewalld"
RULE='rule family="ipv4" source address="192.168.1.0/24" port port="443" protocol="tcp" accept'

die() {
	echo "Error: $*" >&2
	exit 1
}

# First start only: record the package set, so that reset removes
# firewalld again if the lab had to install it
pkg_snapshot firewall-02

command -v nmcli >/dev/null 2>&1 || die "$LAB needs NetworkManager (nmcli)."
systemctl is-active --quiet NetworkManager || die "NetworkManager is not running."

# Re-enable autoconnect on a profile that setup disabled. The change was
# made with --temporary: an in-memory profile is modified back, a
# profile stored on disk is loaded again from its file.
restore_profile() {
	local uuid=$1 file=$2
	nmcli connection modify --temporary uuid "$uuid" connection.autoconnect yes >/dev/null 2>&1 || true
	case "$file" in
		"" | /run/*) ;;
		*) nmcli connection load "$file" >/dev/null 2>&1 || true ;;
	esac
}

# A rerun starts clean: remove the lab connection, restore the profiles
# an earlier run disabled
while read -r uuid; do
	[ -n "$uuid" ] || continue
	nmcli connection delete uuid "$uuid" >/dev/null 2>&1 || true
done < <(nmcli -g UUID,NAME connection show 2>/dev/null | awk -F: -v c="$CONN" '$2 == c { print $1 }')
if [ -r "$STATE_FILE" ]; then
	while IFS= read -r line; do
		case "$line" in
			saved=*)
				line=${line#saved=}
				restore_profile "${line%% *}" "${line#* }"
				;;
		esac
	done < "$STATE_FILE"
fi

# First Ethernet interface that is not the default-route interface, not
# enslaved and not virtual.
default_if=$(ip route show default 2>/dev/null |
	awk '{ for (i = 1; i < NF; i++) if ($i == "dev") { print $(i + 1); exit } }')
[ -n "$default_if" ] || die "no default route found; cannot tell which interface to keep."
iface=
for p in /sys/class/net/*; do
	n=${p##*/}
	[ "$n" = lo ] && continue
	[ "$n" = "$default_if" ] && continue
	[ -e "$p/device" ] || continue
	[ -d "$p/wireless" ] && continue
	[ -e "$p/master" ] && continue
	[ "$(cat "$p/type" 2>/dev/null)" = 1 ] || continue
	iface=$n
	break
done
[ -n "$iface" ] || die "$LAB needs a free Ethernet interface (not the one with the default route) and found none."

# firewalld must be installed and running
if ! command -v firewall-cmd >/dev/null 2>&1; then
	dnf -y install firewalld >/dev/null 2>&1 || die "could not install firewalld."
fi
systemctl enable --now firewalld >/dev/null 2>&1 || die "could not start firewalld."
for _ in $(seq 1 20); do
	firewall-cmd --state >/dev/null 2>&1 && break
	sleep 1
done
firewall-cmd --state >/dev/null 2>&1 || die "firewalld is not responding."

# First start only: keep the permanent firewalld configuration, so that
# reset puts it back exactly. A rerun starts from that copy.
mkdir -p "$STATE_DIR"
if [ -d "$BACKUP/zones" ]; then
	find /etc/firewalld/zones -mindepth 1 -maxdepth 1 -exec rm -rf {} +
	cp -a "$BACKUP/zones/." /etc/firewalld/zones/
	cp -a "$BACKUP/firewalld.conf" /etc/firewalld/firewalld.conf
	restorecon -R /etc/firewalld >/dev/null 2>&1 || true
else
	rm -rf "$BACKUP"
	mkdir -p "$BACKUP"
	cp -a /etc/firewalld/zones "$BACKUP/zones"
	cp -a /etc/firewalld/firewalld.conf "$BACKUP/firewalld.conf"
fi
chmod 700 "$BACKUP"

# Profiles bound to the interface by name or by MAC address
profile_on_iface() {
	local uuid=$1 ifn mac
	ifn=$(nmcli -g connection.interface-name connection show uuid "$uuid" 2>/dev/null) || return 1
	[ "$ifn" = "$iface" ] && return 0
	[ -z "$ifn" ] || return 1
	mac=$(nmcli -g 802-3-ethernet.mac-address connection show uuid "$uuid" 2>/dev/null | tr 'A-F' 'a-f')
	[ -n "$mac" ] && [ "$mac" = "$(cat "/sys/class/net/$iface/address")" ]
}

saved=()
while IFS=: read -r uuid file; do
	[ -n "$uuid" ] || continue
	profile_on_iface "$uuid" || continue
	saved+=("$uuid ${file//\\:/:}")
done < <(nmcli -g UUID,FILENAME connection show 2>/dev/null)

# Record the state before changing the network: the interface on the
# first line (task.txt and the grader read it), then the profiles
{
	echo "$iface"
	for s in ${saved[@]+"${saved[@]}"}; do
		echo "saved=$s"
	done
} > "$STATE_FILE"
chmod 644 "$STATE_FILE"

# Take the profiles out of the way without deleting them. --temporary
# keeps the change in memory, so NetworkManager's automatic profiles are
# not written to disk; cleanup.sh turns autoconnect back on.
for s in ${saved[@]+"${saved[@]}"}; do
	uuid=${s%% *}
	nmcli connection modify --temporary uuid "$uuid" connection.autoconnect no >/dev/null 2>&1 || true
	nmcli connection down uuid "$uuid" >/dev/null 2>&1 || true
done

# Remove the lab rule and any zone binding of the interface from the
# firewalld configuration. No profile is active on the interface now,
# so these changes go to the zone files and not to NetworkManager.
firewall-cmd --permanent --zone=public --remove-rich-rule="$RULE" >/dev/null 2>&1 || true
zone=$(firewall-cmd --permanent --get-zone-of-interface="$iface" 2>/dev/null) || zone=
if [ -n "$zone" ]; then
	firewall-cmd --permanent --zone="$zone" --remove-interface="$iface" >/dev/null 2>&1 || true
fi
firewall-cmd --reload >/dev/null 2>&1 || die "firewall-cmd --reload failed."

# The lab connection: no IP addressing, so it needs no DHCP server and
# stays up; no zone, so the interface is in the default zone. It must
# win against the automatic profile after a reboot.
nmcli connection add type ethernet con-name "$CONN" ifname "$iface" \
	ipv4.method disabled ipv6.method disabled \
	connection.autoconnect yes connection.autoconnect-priority 10 \
	connection.zone "" >/dev/null 2>&1 || die "could not create the connection $CONN on $iface."
if ! nmcli --wait 20 connection up "$CONN" >/dev/null 2>&1; then
	nmcli connection delete "$CONN" >/dev/null 2>&1 || true
	for s in ${saved[@]+"${saved[@]}"}; do
		restore_profile "${s%% *}" "${s#* }"
		nmcli --wait 0 connection up uuid "${s%% *}" >/dev/null 2>&1 || true
	done
	die "the connection $CONN does not come up on $iface (is the link up?)."
fi
