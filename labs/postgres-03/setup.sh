#!/bin/bash
# postgres-03 setup: PostgreSQL installed, initialised and running, with
# database labdb and table users holding sample data. Records in the state
# file what this script did, so that cleanup.sh undoes only that.
# Prints nothing on success.
set -eu

STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/postgres-03"
DATA_DIR=/var/lib/pgsql/data

# Flags: 1 = created or started by this lab (cleanup undoes it)
pkg=0 init=0 svc=0 db=0 tbl=0 rows=0 hash=
if [ -r "$STATE_FILE" ]; then
	for k in pkg init svc db tbl rows; do
		v=$(sed -n "s/^$k=//p" "$STATE_FILE" | head -n 1)
		[ "$v" = 1 ] && printf -v "$k" '%s' 1
	done
fi

save_state() {
	mkdir -p "$STATE_DIR"
	cat > "$STATE_FILE" <<STATE
pkg=$pkg
init=$init
svc=$svc
db=$db
tbl=$tbl
rows=$rows
hash=$hash
STATE
	chmod 644 "$STATE_FILE"
}

# client_min_messages=warning hides NOTICEs such as "does not exist, skipping"
pg() {
	local d=$1 q=$2
	(cd /tmp && PGOPTIONS='-c client_min_messages=warning' runuser -u postgres -- psql -X -At -v ON_ERROR_STOP=1 -d "$d" -c "$q")
}

# Run a command silently (stdout and stderr); show its output only on failure
quiet() {
	local out
	out=$("$@" 2>&1) || { echo "$out" >&2; return 1; }
}

# Package, cluster and service
if ! rpm -q postgresql-server > /dev/null 2>&1; then
	quiet dnf -y -q install postgresql-server
	pkg=1
	save_state
fi
if [ ! -f "$DATA_DIR/PG_VERSION" ]; then
	quiet postgresql-setup --initdb
	init=1
	save_state
fi
if ! systemctl is-active --quiet postgresql; then
	systemctl start postgresql
	svc=1
	save_state
fi
ready=0
for _ in $(seq 1 30); do
	if pg postgres 'SELECT 1' > /dev/null 2>&1; then
		ready=1
		break
	fi
	sleep 1
done
if [ "$ready" -ne 1 ]; then
	echo "postgres-03: PostgreSQL does not accept connections" >&2
	exit 1
fi

# Starting state of the lab: no backup, no restore database
pg postgres 'DROP DATABASE IF EXISTS labdb_restore' > /dev/null
rm -f /tmp/labdb_backup.sql

# labdb: recreate it when this lab made it, otherwise keep what exists
if [ "$db" = 1 ]; then
	pg postgres 'DROP DATABASE IF EXISTS labdb' > /dev/null
fi
if [ "$(pg postgres "SELECT count(*) FROM pg_database WHERE datname = 'labdb'")" = 0 ]; then
	pg postgres 'CREATE DATABASE labdb' > /dev/null
	db=1
	save_state
fi

# users table and rows (only touched when this lab owns them)
if [ "$db" = 0 ]; then
	if [ "$tbl" = 1 ]; then
		pg labdb 'DROP TABLE IF EXISTS public.users' > /dev/null
	fi
	if [ "$rows" = 1 ]; then
		pg labdb 'DELETE FROM public.users' > /dev/null 2>&1 || true
	fi
fi
if [ "$(pg labdb "SELECT count(*) FROM pg_tables WHERE schemaname = 'public' AND tablename = 'users'")" = 0 ]; then
	pg labdb 'CREATE TABLE public.users (id serial PRIMARY KEY, name text NOT NULL, email text NOT NULL)' > /dev/null
	[ "$db" = 1 ] || tbl=1
	save_state
fi
if [ "$(pg labdb 'SELECT count(*) FROM public.users')" = 0 ]; then
	pg labdb "INSERT INTO public.users (name, email) VALUES
		('Alice Novak', 'alice@example.com'),
		('Bruno Horvat', 'bruno@example.com'),
		('Cecilia Kovac', 'cecilia@example.com'),
		('David Babic', 'david@example.com'),
		('Eva Maric', 'eva@example.com')" > /dev/null
	[ "$db" = 1 ] || rows=1
	save_state
fi

# Checksum of the original data for the grader
hash=$(pg labdb 'COPY (SELECT * FROM public.users) TO STDOUT' | sort | md5sum | cut -d' ' -f1)
save_state
