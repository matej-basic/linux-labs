#!/bin/bash
# mysql-01 setup: give the student a machine without a MySQL or MariaDB
# server, so the lab starts from a fresh installation. Prints nothing on
# success.
#
# The first run records the package set (pkg_snapshot); cleanup.sh
# restores it with pkg_restore, so a server package removed here comes
# back at reset. A server that was there before the lab keeps its data:
# the first run also records the service state in the state file and
# puts the data directory, the option files, the log directory and
# root's client files aside in /var/tmp/mysql-01.bak. cleanup.sh puts
# them back.
set -eu
source /opt/linux-labs/lib/packages.sh

STATE_FILE=/opt/linux-labs/state/mysql-01
bak=/var/tmp/mysql-01.bak
servers="mysql-server mariadb-server"
datadir=/var/lib/mysql
# Files and directories restored as they were (only those that exist)
paths="etc/my.cnf etc/my.cnf.d var/log/mysql root/.my.cnf root/.mysql_history"

pkg_snapshot mysql-01

# First run only: what the machine looked like before the lab
if [ ! -r "$STATE_FILE" ]; then
	if [ -e "$bak/datadir" ]; then
		echo "Error: $bak holds a saved MySQL data directory but no" \
			"state file exists. Move it away and start again." >&2
		exit 1
	fi
	rm -rf "$bak"
	mkdir -m 0700 "$bak"
	mkdir -p "$(dirname "$STATE_FILE")"
	tmp="$STATE_FILE.tmp"
	: > "$tmp"
	for u in mysqld mariadb; do
		e=no
		a=no
		systemctl is-enabled --quiet "$u" 2>/dev/null && e=yes
		systemctl is-active --quiet "$u" 2>/dev/null && a=yes
		echo "${u}_enabled=$e" >> "$tmp"
		echo "${u}_active=$a" >> "$tmp"
	done
	systemctl disable --now mysqld mariadb </dev/null >/dev/null 2>&1 || true

	keep=""
	for p in $paths; do
		[ -e "/$p" ] && keep="$keep $p"
	done
	if [ -n "$keep" ]; then
		# shellcheck disable=SC2086 # word splitting is intended
		tar --selinux --xattrs --acls -C / -cpf "$bak/files.tar" $keep
	fi
	if [ -d "$datadir" ] && [ -n "$(ls -A "$datadir")" ]; then
		echo "datadir=yes" >> "$tmp"
		mv "$tmp" "$STATE_FILE"
		mv "$datadir" "$bak/datadir"
	else
		echo "datadir=no" >> "$tmp"
		mv "$tmp" "$STATE_FILE"
	fi
	chmod 644 "$STATE_FILE"
fi

systemctl disable --now mysqld mariadb </dev/null >/dev/null 2>&1 || true

# No server package, so the student installs it
for p in $servers; do
	rpm -q "$p" >/dev/null 2>&1 || continue
	dnf -y remove "$p" </dev/null >/dev/null 2>&1 || {
		echo "Error: could not remove the $p package." >&2
		exit 1
	}
done

# Leftovers of the previous server or of an earlier attempt: data,
# option files saved by rpm, root's client files with an old password
if [ -d "$datadir" ]; then
	find "$datadir" -mindepth 1 -delete
fi
rm -f /etc/my.cnf.rpmsave /etc/my.cnf.d/*.rpmsave
rm -f /root/.my.cnf /root/.mysql_history
