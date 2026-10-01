#!/bin/bash
# postgres-02 setup: a running PostgreSQL server without labdb and
# labuser. Installs and initialises the server only when it is missing.
# Prints nothing on success.
set -eu

STATE_DIR=/opt/linux-labs/state/postgres-02
STATE_FILE="$STATE_DIR/state"
HBA_BACKUP="$STATE_DIR/pg_hba.conf.orig"
DATA=/var/lib/pgsql/data
HBA="$DATA/pg_hba.conf"

die() {
	echo "postgres-02 setup: $*" >&2
	exit 1
}

# client_min_messages=warning hides NOTICEs such as "does not exist, skipping"
pgsu() {
	(cd /tmp && PGOPTIONS='-c client_min_messages=warning' runuser -u postgres -- psql -X -qAt -v ON_ERROR_STOP=1 "$@")
}

# Run a command silently (stdout and stderr); show its output only on failure
quiet() {
	local out
	out=$("$@" 2>&1) || { echo "$out" >&2; return 1; }
}

mkdir -p "$STATE_DIR"
chmod 755 "$STATE_DIR"

# Record the starting state once, so a second run keeps the original
if [ ! -f "$STATE_FILE" ]; then
	pkgs=""
	for p in postgresql-server postgresql; do
		rpm -q "$p" &>/dev/null || pkgs="$pkgs $p"
	done
	initdb=no
	[ -f "$DATA/PG_VERSION" ] || initdb=yes
	was_active=no
	if systemctl is-active --quiet postgresql; then was_active=yes; fi
	{
		echo "pkgs=\"${pkgs# }\""
		echo "initdb=$initdb"
		echo "was_active=$was_active"
	} > "$STATE_FILE"
	chmod 644 "$STATE_FILE"
fi

# Install and initialise the server if needed
if ! rpm -q postgresql-server &>/dev/null; then
	quiet dnf -y -q install postgresql-server || die "cannot install postgresql-server"
fi
if [ ! -f "$DATA/PG_VERSION" ]; then
	quiet postgresql-setup --initdb || die "cannot initialise the database cluster"
fi

# Keep the original pg_hba.conf and return to it on a repeated start
if [ -f "$HBA_BACKUP" ]; then
	cat "$HBA_BACKUP" > "$HBA"
else
	cp -p "$HBA" "$HBA_BACKUP"
fi

systemctl start postgresql || die "cannot start postgresql"
systemctl reload postgresql || die "cannot reload postgresql"

ready=no
for _ in $(seq 1 30); do
	if pgsu -d postgres -c 'SELECT 1' > /dev/null 2>&1; then
		ready=yes
		break
	fi
	sleep 1
done
[ "$ready" = yes ] || die "postgresql does not accept connections"

# Remove what a previous run or the solution left behind
pgsu -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'labdb'" > /dev/null
pgsu -d postgres -c "DROP DATABASE IF EXISTS labdb" > /dev/null
if [ "$(pgsu -d postgres -c "SELECT 1 FROM pg_roles WHERE rolname = 'labuser'")" = 1 ]; then
	for db in $(pgsu -d postgres -c "SELECT datname FROM pg_database WHERE datallowconn"); do
		pgsu -d "$db" -c "DROP OWNED BY labuser" > /dev/null
	done
	pgsu -d postgres -c "DROP ROLE labuser" > /dev/null
fi
