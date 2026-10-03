#!/bin/bash
# redis-01 cleanup: stop Redis, close the firewall openings the lab made
# and restore the package set of the first start (pkg_restore). When the
# lab installed Redis, its configuration, data and logs go before
# pkg_restore, so the redis system user owns no files and is removed
# with the package. A Redis that was there before the lab gets its
# files and service state back afterwards. When the package set cannot
# be restored, the records stay for the next reset and the exit status
# is 1.
source /opt/linux-labs/lib/packages.sh

LAB=redis-01
STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/$LAB"
BACKUP_DIR="$STATE_DIR/$LAB.d"
paths="etc/redis.conf etc/redis-sentinel.conf etc/redis var/lib/redis var/log/redis"

state_value() {
	[ -r "$STATE_FILE" ] || return 0
	sed -n "s/^$1=//p" "$STATE_FILE" | head -n 1
}

systemctl disable --now redis redis-sentinel >/dev/null 2>&1

# Firewall: remove what was not open at the first start
zone=$(state_value zone)
if [ -n "$zone" ] && systemctl is-active --quiet firewalld 2>/dev/null; then
	if [ "$(state_value fw_port)" != yes ]; then
		firewall-cmd --permanent --zone="$zone" --remove-port=6379/tcp >/dev/null 2>&1
		firewall-cmd --zone="$zone" --remove-port=6379/tcp >/dev/null 2>&1
	fi
	if [ "$(state_value fw_service)" != yes ]; then
		firewall-cmd --permanent --zone="$zone" --remove-service=redis >/dev/null 2>&1
		firewall-cmd --zone="$zone" --remove-service=redis >/dev/null 2>&1
	fi
fi

# No Redis before the lab: its files go before pkg_restore, so the redis
# user and group own nothing and can be removed. The rpmsave copies of
# changed configuration files belong to the redis group as well.
if [ -r "$STATE_FILE" ] && ! pkg_was_installed "$LAB" redis; then
	for p in $paths; do
		rm -rf "/${p:?}"
	done
	rm -f /etc/redis.conf.rpm* /etc/redis-sentinel.conf.rpm*
	rm -rf /run/redis
fi

rc=0
pkg_restore "$LAB" || rc=1

# Redis was installed before the lab: pkg_restore installed it again
if [ -d "$BACKUP_DIR" ] && rpm -q redis >/dev/null 2>&1; then
	systemctl stop redis >/dev/null 2>&1
	if [ -f "$BACKUP_DIR/files.tar" ]; then
		for p in $paths; do
			rm -rf "/${p:?}"
		done
		tar --selinux --xattrs --acls -C / -xpf "$BACKUP_DIR/files.tar" || rc=1
		for p in $paths; do
			[ -e "/$p" ] && restorecon -R "/$p" >/dev/null 2>&1
		done
	fi
	[ -f "$BACKUP_DIR/enabled" ] && systemctl enable redis >/dev/null 2>&1
	[ -f "$BACKUP_DIR/active" ] && systemctl start redis >/dev/null 2>&1
fi

if [ "$rc" -eq 0 ]; then
	rm -rf "$BACKUP_DIR"
	rm -f "$STATE_FILE"
fi
exit "$rc"
