#!/bin/bash
# replication-02 setup: PostgreSQL installed on node 1 and node 2, a
# running standalone cluster on node 1 without the lab's role, tables,
# WAL archive and firewall rules, and an empty data directory on node 2
# with PostgreSQL stopped. Prints nothing on success. Nothing on the
# workstation changes except the state file.
#
# The first run records each node's package set (lib/packages.sh), so
# that cleanup.sh removes PostgreSQL again where the lab installed it.
# It also records in /var/tmp/replication-02.pre on each node whether
# postgresql-server and a cluster were there, the boot and running
# state, the firewall rules for PostgreSQL and the .pgpass file of the
# postgres user. Node 1 keeps the configuration files of its cluster in
# the record; node 2 moves the data directory of a cluster that was
# there before the lab to /var/lib/pgsql/replication-02.orig. cleanup.sh
# puts all of it back.
# No "set -u": load-config.sh reads variables that may be unset.
set -e

STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/replication-02"

# shellcheck source=/dev/null
source /opt/linux-labs/lib/load-config.sh
source /opt/linux-labs/lib/packages.sh
load_lab_config

if [[ "$NODES_ENABLED" != "true" ]]; then
	echo "Error: multi-node labs are not enabled (run: sudo labctl configure interactive)." >&2
	exit 1
fi
if [[ "$NODE_COUNT" -lt 2 ]]; then
	echo "Error: this lab needs at least 2 nodes (NODE_COUNT is $NODE_COUNT)." >&2
	exit 1
fi

PRIMARY_IP=$(get_node_ip 1)
STANDBY_IP=$(get_node_ip 2)

for ip in "$PRIMARY_IP" "$STANDBY_IP"; do
	if ! test_node_connectivity "$ip" >/dev/null; then
		echo "Error: node $ip is not reachable over SSH (user $SSH_USER, key $SSH_KEY_PATH)." >&2
		exit 1
	fi
done

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Common part of the node scripts, run as root through "bash -s". The
# whole script is one block with stdin on /dev/null, so no command reads
# the rest of the script.
cat > "$tmp/head.sh" <<'REMOTE'
{
pre=/var/tmp/replication-02.pre
home=/var/lib/pgsql
D=$home/data
FILES="postgresql.conf postgresql.auto.conf pg_hba.conf"

fail() {
	echo "$*" >&2
	exit 1
}

had() {
	grep -qx "$1" "$pre/flags" 2>/dev/null
}

wait_pg() {
	local i
	for i in $(seq 1 30); do
		(cd /tmp && runuser -u postgres -- psql -X -Atq -c 'SELECT 1' >/dev/null 2>&1) && return 0
		sleep 1
	done
	return 1
}

# First run only: what the node looked like before the lab
if [ ! -d "$pre" ]; then
	rm -rf "$pre.tmp"
	mkdir -m 0700 "$pre.tmp" || fail "cannot create $pre"
	{
		if rpm -q postgresql-server >/dev/null 2>&1; then
			echo server-installed
			systemctl is-enabled --quiet postgresql 2>/dev/null && echo enabled
			systemctl is-active --quiet postgresql 2>/dev/null && echo active
		fi
		[ -e "$home" ] && echo home
		[ -f "$D/PG_VERSION" ] && echo data
		firewall-cmd --permanent --query-service=postgresql >/dev/null 2>&1 && echo fw-service
		firewall-cmd --permanent --query-port=5432/tcp >/dev/null 2>&1 && echo fw-port
	} > "$pre.tmp/flags"
	if [ -f "$home/.pgpass" ]; then
		cp "$home/.pgpass" "$pre.tmp/pgpass" || fail "cannot save $home/.pgpass"
	fi
	mv "$pre.tmp" "$pre" || fail "cannot create $pre"
fi

if ! rpm -q postgresql-server >/dev/null 2>&1; then
	dnf -y -q install postgresql-server >/dev/null 2>&1 ||
		fail "installing postgresql-server failed"
fi

# .pgpass of the postgres user as recorded (the solution writes one)
if [ -f "$pre/pgpass" ]; then
	if [ -f "$home/.pgpass" ]; then
		cat "$pre/pgpass" > "$home/.pgpass"
	else
		install -o postgres -g postgres -m 600 "$pre/pgpass" "$home/.pgpass"
		restorecon "$home/.pgpass" 2>/dev/null
	fi
else
	rm -f "$home/.pgpass"
fi

if systemctl is-active --quiet firewalld; then
	firewall-cmd -q --permanent --remove-service=postgresql 2>/dev/null
	firewall-cmd -q --remove-service=postgresql 2>/dev/null
	firewall-cmd -q --permanent --remove-port=5432/tcp 2>/dev/null
	firewall-cmd -q --remove-port=5432/tcp 2>/dev/null
fi
REMOTE

# Node 1: a cluster with the configuration of the first run, no WAL
# archive, no repl role and no test tables, running
cat "$tmp/head.sh" - > "$tmp/primary.sh" <<'REMOTE'
if [ ! -f "$D/PG_VERSION" ]; then
	postgresql-setup --initdb >/dev/null 2>&1 ||
		fail "cannot initialise the database cluster"
fi

# The configuration files of the first run, put back on a repeated start.
# Plain copies: the record is root's, the live files stay postgres'.
if [ ! -d "$pre/conf" ]; then
	rm -rf "$pre/conf.tmp"
	mkdir -m 0700 "$pre/conf.tmp" || fail "cannot save the configuration"
	for f in $FILES; do
		if [ -f "$D/$f" ]; then
			cp "$D/$f" "$pre/conf.tmp/$f" || fail "cannot save $D/$f"
		fi
	done
	mv "$pre/conf.tmp" "$pre/conf" || fail "cannot save the configuration"
else
	for f in $FILES; do
		if [ -f "$pre/conf/$f" ]; then
			cat "$pre/conf/$f" > "$D/$f"
		else
			rm -f "$D/$f"
		fi
	done
fi
rm -rf "$home/wal_archive"

systemctl restart postgresql >/dev/null 2>&1 || fail "postgresql does not start"
wait_pg || fail "postgresql does not accept connections"
cd /tmp || exit 1
runuser -u postgres -- psql -X -q -c 'DROP ROLE IF EXISTS repl' >/dev/null 2>&1
runuser -u postgres -- psql -X -Atq -c "SELECT format('DROP TABLE %I;', tablename) FROM pg_tables WHERE schemaname = 'public' AND tablename ~ '^(repl_test_.*|replication_test)$'" |
	runuser -u postgres -- psql -X -q >/dev/null 2>&1
exit 0
} </dev/null
REMOTE

# Node 2: PostgreSQL stopped and an empty data directory. The data
# directory of a cluster that was there before the lab moves aside once.
cat "$tmp/head.sh" - > "$tmp/standby.sh" <<'REMOTE'
systemctl stop postgresql >/dev/null 2>&1
if had data && [ ! -f "$pre/data-moved" ]; then
	[ ! -e "$home/replication-02.orig" ] ||
		fail "$home/replication-02.orig exists already"
	mv "$D" "$home/replication-02.orig" || fail "cannot move $D aside"
	touch "$pre/data-moved"
fi
rm -rf "$D"
install -d -o postgres -g postgres -m 700 "$D" || fail "cannot create $D"
restorecon -R "$D" 2>/dev/null
exit 0
} </dev/null
REMOTE

n=1
for ip in "$PRIMARY_IP" "$STANDBY_IP"; do
	if [ "$n" -eq 1 ]; then script=primary.sh; else script=standby.sh; fi
	if ! pkg_snapshot_node "$ip" replication-02 > "$tmp/out" 2>&1; then
		echo "Error: recording the packages of node $n ($ip) failed:" >&2
		cat "$tmp/out" >&2
		exit 1
	fi
	if ! run_on_node "$ip" "sudo -n bash -s" < "$tmp/$script" > "$tmp/out" 2>&1; then
		cat "$tmp/out" >&2
		echo "Error: preparing PostgreSQL on node $n ($ip) failed." >&2
		exit 1
	fi
	n=$((n + 1))
done

mkdir -p "$STATE_DIR"
printf 'primary=%s\nstandby=%s\n' "$PRIMARY_IP" "$STANDBY_IP" >"$STATE_FILE"
chmod 644 "$STATE_FILE"
