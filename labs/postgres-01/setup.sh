#!/bin/bash
# postgres-01 setup: refuses to start if PostgreSQL data or a server
# already exists, so no existing database is ever destroyed. Records
# whether the client package was there before the lab. Prints nothing
# on success.
set -eu

STATE_FILE=/opt/linux-labs/state/postgres-01
LAB_DIR=$(dirname "$0")

# A previous run of this lab: undo it first (idempotent start)
if [ -f "$STATE_FILE" ] && [ -x "$LAB_DIR/cleanup.sh" ]; then
	"$LAB_DIR/cleanup.sh" >/dev/null 2>&1 || true
fi

if rpm -q postgresql-server >/dev/null 2>&1; then
	echo "postgres-01: postgresql-server is already installed; remove it first (this lab needs a clean system)." >&2
	exit 1
fi
if [ -n "$(ls -A /var/lib/pgsql/data 2>/dev/null)" ]; then
	echo "postgres-01: /var/lib/pgsql/data is not empty; move it away first (this lab will not touch existing databases)." >&2
	exit 1
fi
if ss -H -tln 'sport = :5432' 2>/dev/null | grep -q .; then
	echo "postgres-01: something already listens on TCP port 5432." >&2
	exit 1
fi

client=no
rpm -q postgresql >/dev/null 2>&1 && client=yes

mkdir -p "$(dirname "$STATE_FILE")"
echo "client=$client" > "$STATE_FILE"
chmod 644 "$STATE_FILE"
