#!/bin/bash
# postgres-02 setup: a running PostgreSQL server without labdb and
# labuser. Installs and initialises the server only when it is missing.
# Prints nothing on success.
#
# The first run records the package set (pkg_snapshot); cleanup.sh
# restores it with pkg_restore, so a server the lab installs goes away
# at reset with its dependencies, module stream and user postgres. An
# existing server (a student machine may have one) is used as it is.
# The first run also records in /var/tmp/postgres-02.pre what else the
# lab may change: whether /var/lib/pgsql and a cluster existed, the
# service state, the firewall service postgresql, the configuration
# files of the cluster, every role with its attributes and password, a
# labdb database that already existed, and the psql history and .pgpass
# files of the task user, root and postgres. cleanup.sh puts all of it
# back.
set -eu
source /opt/linux-labs/lib/packages.sh

STATE_DIR=/opt/linux-labs/state/postgres-02
STATE_FILE="$STATE_DIR/state"
pre=/var/tmp/postgres-02.pre
home=/var/lib/pgsql
DATA=$home/data
CONF_FILES="pg_hba.conf pg_ident.conf postgresql.conf postgresql.auto.conf"

lab_user=${LAB_USER:-student}
if ! getent passwd "$lab_user" >/dev/null; then
	lab_user=$(getent passwd | awk -F: '$3 >= 1000 && $3 < 60000 { print $1; exit }')
fi
lab_home=$(getent passwd "$lab_user" | cut -d: -f6)

die() {
	echo "postgres-02 setup: $*" >&2
	exit 1
}

pkg_snapshot postgres-02 || die "cannot record the package set"

# client_min_messages=warning hides NOTICEs such as "does not exist, skipping"
pgsu() {
	(cd /tmp && PGOPTIONS='-c client_min_messages=warning' runuser -u postgres -- psql -X -qAt -v ON_ERROR_STOP=1 "$@")
}

# Run a command silently (stdout and stderr); show its output only on failure
quiet() {
	local out
	out=$("$@" 2>&1) || { echo "$out" >&2; return 1; }
}

# First run only: what the machine looked like before the lab
if [ ! -d "$pre" ]; then
	rm -rf "$pre.tmp"
	mkdir -m 0700 "$pre.tmp" "$pre.tmp/files"
	flags="$pre.tmp/flags"
	: > "$flags"
	[ -e "$home" ] && echo home >> "$flags"
	[ -f "$DATA/PG_VERSION" ] && echo data >> "$flags"
	systemctl is-enabled --quiet postgresql 2>/dev/null && echo enabled >> "$flags"
	systemctl is-active --quiet postgresql 2>/dev/null && echo active >> "$flags"
	if firewall-cmd --state >/dev/null 2>&1; then
		echo firewalld >> "$flags"
		firewall-cmd --query-service=postgresql >/dev/null 2>&1 &&
			echo fw-runtime >> "$flags"
		firewall-cmd --permanent --query-service=postgresql >/dev/null 2>&1 &&
			echo fw-permanent >> "$flags"
	fi
	for h in "$lab_home" /root "$home"; do
		[ -n "$h" ] || continue
		for f in .psql_history .pgpass; do
			[ -f "$h/$f" ] || continue
			echo "$h/$f" >> "$pre.tmp/files.list"
			cp -p "$h/$f" "$pre.tmp/files/$(echo "$h/$f" | tr / %)"
		done
	done
	touch "$pre.tmp/files.list"
	mv "$pre.tmp" "$pre"
fi

# Install and initialise the server if needed
if ! rpm -q postgresql-server &>/dev/null; then
	quiet dnf -y -q install postgresql-server </dev/null ||
		die "cannot install postgresql-server"
fi
if [ ! -f "$DATA/PG_VERSION" ]; then
	quiet postgresql-setup --initdb || die "cannot initialise the database cluster"
fi

# First run: keep the configuration files. A repeated start puts them
# back, so it begins from the same configuration.
restart=no
if [ ! -d "$pre/conf" ]; then
	mkdir -m 0700 "$pre/conf.tmp"
	for f in $CONF_FILES; do
		[ -f "$DATA/$f" ] && cp "$DATA/$f" "$pre/conf.tmp/$f"
	done
	mv "$pre/conf.tmp" "$pre/conf"
else
	for f in $CONF_FILES; do
		[ -f "$pre/conf/$f" ] || continue
		cmp -s "$pre/conf/$f" "$DATA/$f" && continue
		cat "$pre/conf/$f" > "$DATA/$f"
		restart=yes
	done
fi

if [ "$restart" = yes ] && systemctl is-active --quiet postgresql; then
	systemctl restart postgresql || die "cannot restart postgresql"
else
	systemctl start postgresql || die "cannot start postgresql"
fi

ready=no
for _ in $(seq 1 30); do
	if pgsu -d postgres -c 'SELECT 1' > /dev/null 2>&1; then
		ready=yes
		break
	fi
	sleep 1
done
[ "$ready" = yes ] || die "postgresql does not accept connections"

# First run: save every role (attributes, passwords, memberships) and a
# labdb that already exists
if [ ! -f "$pre/saved" ]; then
	(cd /tmp && runuser -u postgres -- pg_dumpall --roles-only) \
		> "$pre/roles.sql" 2>/dev/null || die "cannot save the roles"
	pgsu -d postgres -c "SELECT format('ALTER ROLE %I PASSWORD NULL;', rolname) FROM pg_authid WHERE rolpassword IS NULL AND rolname !~ '^pg_'" \
		>> "$pre/roles.sql" || die "cannot save the roles"
	if [ "$(pgsu -d postgres -c "SELECT 1 FROM pg_database WHERE datname = 'labdb'")" = 1 ]; then
		(cd /tmp && runuser -u postgres -- pg_dump --create -d labdb) \
			> "$pre/labdb.sql" 2>/dev/null || die "cannot save the existing database labdb"
	fi
	touch "$pre/saved"
else
	# A repeated start: the roles as they were before the lab
	(cd /tmp && runuser -u postgres -- psql -X -q -d postgres) \
		< "$pre/roles.sql" > /dev/null 2>&1 || true
fi

# Remove what a previous run or the solution left behind
pgsu -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'labdb'" > /dev/null
pgsu -d postgres -c "DROP DATABASE IF EXISTS labdb" > /dev/null
if [ "$(pgsu -d postgres -c "SELECT 1 FROM pg_roles WHERE rolname = 'labuser'")" = 1 ]; then
	for db in $(pgsu -d postgres -c "SELECT datname FROM pg_database WHERE datallowconn"); do
		pgsu -d "$db" -c "DROP OWNED BY labuser" > /dev/null
	done
	pgsu -d postgres -c "DROP ROLE labuser" > /dev/null
fi

mkdir -p "$STATE_DIR"
chmod 755 "$STATE_DIR"
echo started > "$STATE_FILE"
chmod 644 "$STATE_FILE"
exit 0
