#!/bin/bash
# postgres-02 cleanup: remove labdb and labuser, restore pg_hba.conf and
# undo what setup.sh installed or started.
STATE_DIR=/opt/linux-labs/state/postgres-02
STATE_FILE="$STATE_DIR/state"
HBA_BACKUP="$STATE_DIR/pg_hba.conf.orig"
DATA=/var/lib/pgsql/data

pgsu() {
	(cd /tmp && runuser -u postgres -- psql -X -qAt "$@")
}

# Never started: nothing to undo
[ -f "$STATE_FILE" ] || exit 0

pkgs=""
initdb=no
was_active=no
# shellcheck disable=SC1090 # state file written by setup.sh
. "$STATE_FILE"

if [ -f "$HBA_BACKUP" ] && [ -d "$DATA" ]; then
	cat "$HBA_BACKUP" > "$DATA/pg_hba.conf"
fi

if systemctl is-active --quiet postgresql; then
	pgsu -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'labdb'" > /dev/null 2>&1
	pgsu -d postgres -c "DROP DATABASE IF EXISTS labdb" > /dev/null 2>&1
	if [ "$(pgsu -d postgres -c "SELECT 1 FROM pg_roles WHERE rolname = 'labuser'" 2>/dev/null)" = 1 ]; then
		for db in $(pgsu -d postgres -c "SELECT datname FROM pg_database WHERE datallowconn" 2>/dev/null); do
			pgsu -d "$db" -c "DROP OWNED BY labuser" > /dev/null 2>&1
		done
		pgsu -d postgres -c "DROP ROLE labuser" > /dev/null 2>&1
	fi
	systemctl reload postgresql > /dev/null 2>&1
fi

if [ "$initdb" = yes ]; then
	systemctl stop postgresql > /dev/null 2>&1
	rm -rf "$DATA"
elif [ "$was_active" = no ]; then
	systemctl stop postgresql > /dev/null 2>&1
fi

if [ -n "$pkgs" ]; then
	read -r -a pkg_list <<< "$pkgs"
	dnf -y -q remove "${pkg_list[@]}" > /dev/null 2>&1
fi

rm -rf "$STATE_DIR"
exit 0
