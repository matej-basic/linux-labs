#!/bin/bash
# postgres-01 setup: give the student a machine without PostgreSQL, so the
# lab starts from a fresh installation. Prints nothing on success.
#
# The first run records the package set (pkg_snapshot); cleanup.sh
# restores it with pkg_restore, so a postgresql* package removed here
# comes back at reset. A server that was there before the lab keeps its
# data: the first run also records the service state in the state file
# and puts /var/lib/pgsql (data directory included) aside in
# /var/tmp/postgres-01.bak. cleanup.sh puts it back.
set -eu
source /opt/linux-labs/lib/packages.sh

STATE_FILE=/opt/linux-labs/state/postgres-01
bak=/var/tmp/postgres-01.bak
home=/var/lib/pgsql

pkg_snapshot postgres-01

# First run only: what the machine looked like before the lab
if [ ! -r "$STATE_FILE" ]; then
	if [ -e "$bak/pgsql" ]; then
		echo "Error: $bak holds a saved $home but no state file" \
			"exists. Move it away and start again." >&2
		exit 1
	fi
	rm -rf "$bak"
	mkdir -m 0700 "$bak"
	mkdir -p "$(dirname "$STATE_FILE")"
	tmp="$STATE_FILE.tmp"
	e=no
	a=no
	systemctl is-enabled --quiet postgresql 2>/dev/null && e=yes
	systemctl is-active --quiet postgresql 2>/dev/null && a=yes
	{
		echo "enabled=$e"
		echo "active=$a"
	} > "$tmp"
	systemctl disable --now postgresql </dev/null >/dev/null 2>&1 || true
	if [ -e "$home" ]; then
		echo "home=yes" >> "$tmp"
		mv "$tmp" "$STATE_FILE"
		mv "$home" "$bak/pgsql"
	else
		echo "home=no" >> "$tmp"
		mv "$tmp" "$STATE_FILE"
	fi
	chmod 644 "$STATE_FILE"
fi

systemctl disable --now postgresql </dev/null >/dev/null 2>&1 || true

# No postgresql* package, so the student installs PostgreSQL
pkgs=$(rpm -qa --qf '%{NAME}\n' 'postgresql*' | sort -u)
if [ -n "$pkgs" ]; then
	# shellcheck disable=SC2086 # word splitting is intended
	dnf -y remove $pkgs </dev/null >/dev/null 2>&1 || {
		echo "Error: could not remove the PostgreSQL packages." >&2
		exit 1
	}
fi

# Leftovers of an earlier attempt: data directory, logs, unit drop-ins
rm -rf "$home" /etc/systemd/system/postgresql.service.d
systemctl daemon-reload </dev/null >/dev/null 2>&1 || true
