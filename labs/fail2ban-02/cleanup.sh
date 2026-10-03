#!/bin/bash
# fail2ban-02 cleanup: stops fail2ban, removes its configuration, its
# database and log and the log of labapp, drops the runtime firewall
# rules and sets of its bans, then restores the package set (fail2ban,
# EPEL and its signing key go, and so do the repository files). A
# fail2ban that was there before the lab gets its configuration and
# service state back.
source /opt/linux-labs/lib/packages.sh

LAB=fail2ban-02
STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/$LAB"
DATA_DIR="$STATE_DIR/$LAB.d"
BACKUP_DIR="$DATA_DIR/backup"

rc=0

if [ -f "$STATE_FILE" ]; then
	# Stopping fail2ban unbans every address it banned
	systemctl disable --now fail2ban >/dev/null 2>&1
	rm -rf /etc/fail2ban /var/lib/fail2ban /run/fail2ban
	rm -f /var/log/fail2ban.log*

	if systemctl is-active --quiet firewalld; then
		# ipsets of the ipset ban actions, if the student chose one
		for s in $(firewall-cmd --permanent --get-ipsets 2>/dev/null); do
			case $s in
			f2b-*) firewall-cmd --permanent --delete-ipset="$s" >/dev/null 2>&1 ;;
			esac
		done
		# A reload drops the runtime rich rules, direct rules and ipsets
		# that bans add; fail2ban never writes permanent rules
		firewall-cmd --reload >/dev/null 2>&1 || rc=1
	fi
	if command -v ipset >/dev/null 2>&1; then
		for s in $(ipset list -n 2>/dev/null); do
			case $s in
			f2b-*) ipset destroy "$s" >/dev/null 2>&1 ;;
			esac
		done
	fi
fi
rm -rf /var/log/labapp

pkg_restore "$LAB" || rc=1

# fail2ban was installed before the lab: pkg_restore installed it again
if [ -d "$BACKUP_DIR" ] && rpm -q fail2ban-server >/dev/null 2>&1; then
	if [ -d "$BACKUP_DIR/etc-fail2ban" ]; then
		rm -rf /etc/fail2ban
		cp -a "$BACKUP_DIR/etc-fail2ban" /etc/fail2ban
		restorecon -R /etc/fail2ban >/dev/null 2>&1
	fi
	[ -f "$BACKUP_DIR/enabled" ] && systemctl enable fail2ban >/dev/null 2>&1
	[ -f "$BACKUP_DIR/active" ] && systemctl start fail2ban >/dev/null 2>&1
fi

if [ "$rc" -eq 0 ]; then
	rm -rf "$DATA_DIR"
	rm -f "$STATE_FILE"
fi
exit "$rc"
