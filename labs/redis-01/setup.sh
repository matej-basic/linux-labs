#!/bin/bash
# redis-01 setup: start without Redis. The redis package is removed if it
# is installed, its configuration and data with it, and nothing else may
# hold port 6379. Prints nothing on success.
#
# The first run records the package set (pkg_snapshot), the address of
# the default-route interface (the task points the student to it) and
# whether port 6379/tcp or the redis firewall service was open before.
# A Redis that was installed before the lab is put aside in
# /opt/linux-labs/state/redis-01.d (configuration, data directory,
# service state); cleanup.sh puts it back after pkg_restore has
# installed the package again.
set -eu
source /opt/linux-labs/lib/packages.sh

LAB=redis-01
STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/$LAB"
BACKUP_DIR="$STATE_DIR/$LAB.d"
# Files and directories of the redis package (Rocky 8 and 9 layouts)
paths="etc/redis.conf etc/redis-sentinel.conf etc/redis var/lib/redis var/log/redis"

if ! command -v firewall-cmd >/dev/null 2>&1 \
	|| ! systemctl is-active --quiet firewalld 2>/dev/null; then
	echo "Error: firewalld is not running on this machine." >&2
	exit 1
fi

dev=$(ip -4 route show default 2>/dev/null | awk '{ for (i = 1; i < NF; i++) if ($i == "dev") { print $(i + 1); exit } }')
addr=
if [ -n "$dev" ]; then
	addr=$(ip -4 -o addr show dev "$dev" scope global 2>/dev/null | awk '{ sub(/\/.*/, "", $4); print $4; exit }')
fi
if [ -z "$addr" ]; then
	echo "Error: no IPv4 address on the default-route interface." >&2
	exit 1
fi
zone=$(firewall-cmd --get-zone-of-interface="$dev" 2>/dev/null || true)
[ -n "$zone" ] || zone=$(firewall-cmd --get-default-zone)

pkg_snapshot "$LAB"

# First run only: what the machine looked like before the lab
if [ ! -r "$STATE_FILE" ]; then
	rm -rf "$BACKUP_DIR"
	mkdir -p "$STATE_DIR"
	fw_port=no
	fw_service=no
	firewall-cmd --permanent --zone="$zone" --query-port=6379/tcp >/dev/null 2>&1 && fw_port=yes
	firewall-cmd --permanent --zone="$zone" --query-service=redis >/dev/null 2>&1 && fw_service=yes
	if rpm -q redis >/dev/null 2>&1; then
		mkdir -m 0700 "$BACKUP_DIR"
		systemctl is-enabled --quiet redis 2>/dev/null && touch "$BACKUP_DIR/enabled"
		systemctl is-active --quiet redis 2>/dev/null && touch "$BACKUP_DIR/active"
		systemctl stop redis >/dev/null 2>&1 || true
		keep=""
		for p in $paths; do
			[ -e "/$p" ] && keep="$keep $p"
		done
		if [ -n "$keep" ]; then
			# shellcheck disable=SC2086 # word splitting is intended
			tar --selinux --xattrs --acls -C / -cpf "$BACKUP_DIR/files.tar" $keep
		fi
	fi
	tmp="$STATE_FILE.tmp"
	{
		echo "address=$addr"
		echo "device=$dev"
		echo "zone=$zone"
		echo "fw_port=$fw_port"
		echo "fw_service=$fw_service"
	} > "$tmp"
	chmod 644 "$tmp"
	mv "$tmp" "$STATE_FILE"
fi

# No Redis, as the task starts
systemctl disable --now redis >/dev/null 2>&1 || true
if rpm -q redis >/dev/null 2>&1; then
	dnf -y remove redis </dev/null >/dev/null 2>&1 || {
		echo "Error: could not remove the redis package." >&2
		exit 1
	}
fi

# Configuration, data and logs of the removed Redis or of an earlier
# attempt (a Redis from before the lab is saved in $BACKUP_DIR)
for p in $paths; do
	rm -rf "/${p:?}"
done
rm -f /etc/redis.conf.rpm* /etc/redis-sentinel.conf.rpm*

# Firewall openings of an earlier attempt, unless they were there before
state_value() {
	sed -n "s/^$1=//p" "$STATE_FILE" | head -n 1
}
zone=$(state_value zone)
if [ "$(state_value fw_port)" != yes ]; then
	firewall-cmd --permanent --zone="$zone" --remove-port=6379/tcp >/dev/null 2>&1 || true
	firewall-cmd --zone="$zone" --remove-port=6379/tcp >/dev/null 2>&1 || true
fi
if [ "$(state_value fw_service)" != yes ]; then
	firewall-cmd --permanent --zone="$zone" --remove-service=redis >/dev/null 2>&1 || true
	firewall-cmd --zone="$zone" --remove-service=redis >/dev/null 2>&1 || true
fi

if [ -n "$(ss -H -tln 'sport = :6379' 2>/dev/null)" ]; then
	echo "Error: another service already listens on TCP port 6379." >&2
	exit 1
fi
