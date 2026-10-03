#!/bin/bash
# fail2ban-02 setup: fail2ban removed with its configuration and
# database, firewalld running, and the log of the application labapp
# written to /var/log/labapp/auth.log. The grader gets a pristine copy
# of the log, a copy without the failed logins, the number of failed
# logins and the network of the default-route interface. Prints nothing
# on success.
#
# On the first start the package set (EPEL and its key included) is
# recorded, so that reset removes everything the lab installs. If
# fail2ban was installed before the lab, its configuration and service
# state are saved and cleanup puts them back.
set -eu
source /opt/linux-labs/lib/packages.sh

LAB=fail2ban-02
STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/$LAB"
DATA_DIR="$STATE_DIR/$LAB.d"
BACKUP_DIR="$DATA_DIR/backup"
LOG_DIR=/var/log/labapp
LOG="$LOG_DIR/auth.log"

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
	rm -rf "$DATA_DIR"
	mkdir -m 755 "$DATA_DIR"
	if rpm -q fail2ban-server >/dev/null 2>&1; then
		mkdir -m 700 "$BACKUP_DIR"
		[ -d /etc/fail2ban ] && cp -a /etc/fail2ban "$BACKUP_DIR/etc-fail2ban"
		systemctl is-enabled --quiet fail2ban 2>/dev/null && touch "$BACKUP_DIR/enabled"
		systemctl is-active --quiet fail2ban 2>/dev/null && touch "$BACKUP_DIR/active"
	fi
fi
mkdir -p "$DATA_DIR"
chmod 755 "$DATA_DIR"

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

# The application log. All addresses are documentation addresses
# (TEST-NET-1, -2 and -3). The lines start two days ago, so a jail
# ignores them as older than its findtime. 98 lines, 37 failed logins.
ips=(192.0.2.15 198.51.100.7 203.0.113.9 192.0.2.41 198.51.100.23
	203.0.113.40 192.0.2.130 198.51.100.200 203.0.113.77)
users=(admin backup deploy guest oracle webdev test operator ftp)
reasons=(badpass nouser badpass locked badpass expired)
start=$(($(date +%s) - 2 * 86400))
rm -rf "$LOG_DIR"
mkdir -m 755 "$LOG_DIR"
: > "$DATA_DIR/auth.log"
: > "$DATA_DIR/other.log"
fails=0
for j in $(seq 0 97); do
	ts=$(date -d "@$((start + j * 47))" +%Y-%m-%dT%H:%M:%S)
	ip=${ips[$((j * 5 % 9))]}
	u=${users[$((j * 7 % 9))]}
	pid=$((3100 + j / 11))
	other=1
	case $((j % 8)) in
	0 | 2 | 5)
		line="LOGIN FAILED user=$u src=$ip reason=${reasons[$((j % 6))]}"
		other=0
		fails=$((fails + 1))
		;;
	1 | 6) line="LOGIN OK user=$u src=$ip method=password" ;;
	3) line="SESSION CLOSED user=$u src=$ip duration=$((j * 13))s" ;;
	4) line="PASSWORD RESET FAILED user=$u src=$ip reason=badtoken" ;;
	7)
		if [ $((j % 16)) -eq 7 ]; then
			line="ADMIN UNLOCK user=$u by=root note=\"LOGIN FAILED user=$u src=$ip reason=locked\""
		else
			line="LOGIN OK user=$u src=$ip method=publickey"
		fi
		;;
	esac
	line="$ts labapp[$pid]: $line"
	echo "$line" >> "$DATA_DIR/auth.log"
	[ "$other" = 1 ] && echo "$line" >> "$DATA_DIR/other.log"
done
cp "$DATA_DIR/auth.log" "$LOG"
chmod 640 "$LOG"
chmod 644 "$DATA_DIR/auth.log" "$DATA_DIR/other.log"
restorecon -R "$LOG_DIR" >/dev/null 2>&1 || true

{
	echo "owner=${LAB_USER:-student}"
	echo "net=$net"
	echo "fails=$fails"
} > "$STATE_FILE"
chmod 644 "$STATE_FILE"
exit 0
