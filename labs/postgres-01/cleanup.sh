#!/bin/bash
# postgres-01 cleanup: undoes the solution (packages, data, service) and
# removes the state file. Does nothing destructive if the lab was never
# started, so a database that existed before is left alone.

STATE_FILE=/opt/linux-labs/state/postgres-01

if [ -f "$STATE_FILE" ]; then
	systemctl stop postgresql >/dev/null 2>&1 || true
	systemctl disable postgresql >/dev/null 2>&1 || true

	pkgs=""
	for p in postgresql-server postgresql-contrib; do
		rpm -q "$p" >/dev/null 2>&1 && pkgs="$pkgs $p"
	done
	if ! grep -qx 'client=yes' "$STATE_FILE" && rpm -q postgresql >/dev/null 2>&1; then
		pkgs="$pkgs postgresql"
	fi
	# shellcheck disable=SC2086 # intentional word splitting of the package list
	[ -z "$pkgs" ] || dnf remove -y $pkgs >/dev/null 2>&1 || true

	rm -rf /var/lib/pgsql/data /var/lib/pgsql/initdb_postgresql.log
	rm -f /etc/systemd/system/multi-user.target.wants/postgresql.service
fi

rm -f "$STATE_FILE"
exit 0
