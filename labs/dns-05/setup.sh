#!/bin/bash
# dns-05 setup: records the name resolution configuration at the first
# start (/etc/hosts, /etc/resolv.conf as a file or a symlink, and the
# NetworkManager configuration in NetworkManager.conf, the conf.d
# directories of /etc and /run), restores it on a restart, and records
# the connection of the default-route interface: its profile file
# checksum, its DNS properties and the DNS servers NetworkManager has
# for it. Then it breaks name resolution in three places:
#   - /etc/NetworkManager/conf.d/90-lab.conf sets dns=none, so
#     NetworkManager stops writing /etc/resolv.conf
#   - /etc/resolv.conf points at 192.0.2.53 (TEST-NET-1, unreachable)
#     and carries the immutable attribute
#   - /etc/hosts maps www.rockylinux.org to 192.0.2.80
# The connection profile of the default-route interface is never
# touched. Prints nothing on success.
set -eu
source /opt/linux-labs/lib/packages.sh

LAB="dns-05"
STATE_DIR=/opt/linux-labs/state
STATE=$STATE_DIR/$LAB
ORIG=$STATE_DIR/$LAB.orig
LABCONF=/etc/NetworkManager/conf.d/90-lab.conf
BAD_NS=192.0.2.53
BAD_WWW=192.0.2.80
WWW=www.rockylinux.org
PUBLIC=rockylinux.org
FIELDS=connection.id,connection.uuid,connection.interface-name
FIELDS=$FIELDS,connection.autoconnect,ipv4.method,ipv4.addresses
FIELDS=$FIELDS,ipv4.gateway,ipv4.dns,ipv4.dns-search,ipv4.ignore-auto-dns
FIELDS=$FIELDS,ipv6.method,ipv6.dns,ipv6.dns-search,ipv6.ignore-auto-dns

# The properties of a connection profile that the grader compares (the
# same function is in grade.sh)
profile_fields() {
	nmcli -g "$FIELDS" connection show uuid "$1" 2>/dev/null
}

fail() {
	echo "$LAB: $*" >&2
	exit 1
}

for c in nmcli NetworkManager chattr lsattr getent sha256sum; do
	command -v "$c" >/dev/null 2>&1 || fail "the command $c is missing"
done
systemctl is-active --quiet NetworkManager || fail "NetworkManager is not running"

pkg_snapshot "$LAB"

# A restart puts back what the first start recorded
if [ -d "$ORIG" ]; then
	bash "$(dirname "$0")/cleanup.sh" --leftovers ||
		fail "cannot restore the configuration of the first start"
fi

# The configuration at the first start
if [ ! -f "$ORIG/done" ]; then
	rm -rf "$ORIG"
	mkdir -p "$ORIG/conf.d"
	chmod 700 "$ORIG"
	cp -p /etc/hosts "$ORIG/hosts"
	if [ -L /etc/resolv.conf ]; then
		readlink /etc/resolv.conf > "$ORIG/resolv.link"
	elif [ -e /etc/resolv.conf ]; then
		cp -p /etc/resolv.conf "$ORIG/resolv.conf"
	fi
	[ ! -f /etc/NetworkManager/NetworkManager.conf ] ||
		cp -p /etc/NetworkManager/NetworkManager.conf "$ORIG/NetworkManager.conf"
	for f in /etc/NetworkManager/conf.d/*; do
		[ -f "$f" ] && cp -p "$f" "$ORIG/conf.d/"
	done
	ls -1A /run/NetworkManager/conf.d 2>/dev/null > "$ORIG/run-conf.d" || true
	touch "$ORIG/done"
fi

# The connection of the default-route interface
defif=$(ip -4 route show default 2>/dev/null |
	awk '{ for (i = 1; i < NF; i++) if ($i == "dev") { print $(i + 1); exit } }')
[ -n "$defif" ] || fail "no default route found"
uuid=$(nmcli -g GENERAL.CON-UUID device show "$defif" 2>/dev/null)
[ -n "$uuid" ] || fail "the default-route interface $defif has no active NetworkManager connection"
con=$(nmcli -g connection.id connection show uuid "$uuid")
file=$(nmcli -g UUID,FILENAME connection show 2>/dev/null |
	sed -n "s/^$uuid://p" | sed 's/\\:/:/g')
dns=$(nmcli -g IP4.DNS,IP6.DNS device show "$defif" 2>/dev/null |
	sed 's/\\:/:/g; s/[[:space:]|]\{1,\}/\n/g' | sed '/^$/d' | sort -u)
[ -n "$dns" ] || fail "NetworkManager has no DNS servers for $defif; the lab needs them"

if ! timeout 25 getent ahosts "$PUBLIC" >/dev/null 2>&1; then
	fail "$PUBLIC does not resolve before the lab; the lab needs working DNS"
fi

rm -rf "$STATE"
mkdir -p "$STATE"
chmod 755 "$STATE"
{
	echo "iface=$defif"
	echo "uuid=$uuid"
	echo "con=$con"
	echo "file=$file"
} > "$STATE/info"
printf '%s\n' "$dns" > "$STATE/dns"
profile_fields "$uuid" > "$STATE/profile"
if [ -n "$file" ] && [ -f "$file" ]; then
	sha256sum "$file" > "$STATE/profile.sha256"
else
	: > "$STATE/profile.sha256"
fi

# Break it: NetworkManager stops managing /etc/resolv.conf
printf '[main]\ndns=none\n' > "$LABCONF"
chmod 644 "$LABCONF"
restorecon "$LABCONF" >/dev/null 2>&1 || true
nmcli general reload >/dev/null 2>&1 || fail "cannot reload NetworkManager"
sleep 1

search=$(grep -E '^(search|domain)[[:space:]]' "$ORIG/resolv.conf" 2>/dev/null || true)
chattr -i -a /etc/resolv.conf >/dev/null 2>&1 || true
rm -f /etc/resolv.conf
{
	echo "# Static resolver configuration, do not change"
	[ -z "$search" ] || printf '%s\n' "$search"
	echo "nameserver $BAD_NS"
} > /etc/resolv.conf
chmod 644 /etc/resolv.conf
restorecon /etc/resolv.conf >/dev/null 2>&1 || true
chattr +i /etc/resolv.conf || fail "cannot set the immutable attribute on /etc/resolv.conf"

printf '%s   %s\n' "$BAD_WWW" "$WWW" >> /etc/hosts

chmod 644 "$STATE"/*
