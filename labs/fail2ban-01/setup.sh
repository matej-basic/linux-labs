#!/bin/bash
# fail2ban-01 setup: fail2ban removed with its configuration and
# database, firewalld running, and the network of the default-route
# interface recorded for the grader. Prints nothing on success.
#
# On the first start the package set (EPEL and its key included) is
# recorded, so that reset removes everything the lab installs. If
# fail2ban was installed before the lab, its configuration and service
# state are saved and cleanup puts them back.
set -eu
source /opt/linux-labs/lib/packages.sh

LAB=fail2ban-01
STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/$LAB"
BACKUP_DIR="$STATE_DIR/$LAB.d"

command -v dnf >/dev/null 2>&1 || { echo "setup: dnf not found" >&2; exit 1; }
if ! systemctl is-active --quiet firewalld || ! firewall-cmd --state >/dev/null 2>&1; then
	echo "setup: firewalld is not running; the lab needs it for the bans" >&2
	exit 1
fi

# The IPv4 network of the interface that carries the default route
dev=$(ip -4 route show default | awk '{ for (i = 1; i < NF; i++) if ($i == "dev") { print $(i + 1); exit } }')
net=""
if [ -n "$dev" ]; then
	net=$(ip -4 route show dev "$dev" scope link proto kernel | awk '$1 ~ /\// { print $1; exit }')
fi
case $net in
*.*.*.*/*) ;;
*)
	echo "setup: cannot find the network of the default-route interface" >&2
	exit 1
	;;
esac

# First start only: record the package set before any dnf change
pkg_snapshot "$LAB"

# First start only: keep the configuration of a fail2ban that was there
# before the lab
if [ ! -f "$STATE_FILE" ]; then
	rm -rf "$BACKUP_DIR"
	if rpm -q fail2ban-server >/dev/null 2>&1; then
		mkdir -m 700 "$BACKUP_DIR"
		[ -d /etc/fail2ban ] && cp -a /etc/fail2ban "$BACKUP_DIR/etc-fail2ban"
		systemctl is-enabled --quiet fail2ban 2>/dev/null && touch "$BACKUP_DIR/enabled"
		systemctl is-active --quiet fail2ban 2>/dev/null && touch "$BACKUP_DIR/active"
	fi
fi

# Stopping fail2ban removes its bans from the firewall
systemctl disable --now fail2ban >/dev/null 2>&1 || true
if rpm -qa 'fail2ban*' | grep -q .; then
	# shellcheck disable=SC2046 # one word per package name
	dnf -y -q remove $(rpm -qa --qf '%{NAME}\n' 'fail2ban*') >/dev/null 2>&1 || {
		echo "setup: cannot remove the fail2ban packages" >&2
		exit 1
	}
fi
rm -rf /etc/fail2ban /var/lib/fail2ban /run/fail2ban
rm -f /var/log/fail2ban.log*
# Runtime firewall rules or sets left by an earlier run
firewall-cmd --reload >/dev/null 2>&1 || true

mkdir -p "$STATE_DIR"
{
	echo "owner=${LAB_USER:-student}"
	echo "net=$net"
} > "$STATE_FILE"
chmod 644 "$STATE_FILE"
exit 0
