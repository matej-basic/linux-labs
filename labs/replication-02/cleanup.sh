#!/bin/bash
# replication-02 cleanup: puts nodes 1 and 2 back into the state that the
# first setup.sh run recorded in /var/tmp/replication-02.pre. Where the
# lab installed PostgreSQL, /var/lib/pgsql goes first, so that the
# postgres account owns no file, and then the package set of the first
# start comes back (lib/packages.sh), which removes PostgreSQL with its
# dependencies, module stream and the postgres user and group. Where
# PostgreSQL was there before, the repl role, the test tables, the WAL
# archive and the cluster copy of the solution go, and the configuration
# files, the data directory moved aside on node 2, the .pgpass file and
# the boot and running state come back as recorded. The firewall rules
# for PostgreSQL go back to their recorded values. When a node cannot be
# restored, its records stay for the next reset and the exit status is 1.
# No "set -u": load-config.sh reads variables that may be unset.

# shellcheck source=/dev/null
source /opt/linux-labs/lib/load-config.sh
source /opt/linux-labs/lib/packages.sh
load_lab_config

rm -f /opt/linux-labs/state/replication-02

# Nothing was started without multi-node support
[[ "$NODES_ENABLED" == "true" ]] || exit 0
[[ "$NODE_COUNT" -ge 2 ]] 2>/dev/null || exit 0

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Before the package restore: remove the lab's objects and files, stop
# PostgreSQL. Run as root on a node through "bash -s"; stdin of every
# command is /dev/null.
cat > "$tmp/stop.sh" <<'REMOTE'
{
pre=/var/tmp/replication-02.pre
home=/var/lib/pgsql
D=$home/data
ORIG=$home/replication-02.orig

# setup.sh never recorded this node, so it installed nothing here
[ -d "$pre" ] || exit 0

had() {
	grep -qx "$1" "$pre/flags" 2>/dev/null
}

pgsql() {
	(cd /tmp && runuser -u postgres -- psql -X -q "$@")
}

if had server-installed; then
	# A server from before the lab: remove only what the lab added.
	# The test tables and the role exist on node 1 only.
	if [ -d "$pre/conf" ] && systemctl start postgresql >/dev/null 2>&1; then
		for i in $(seq 1 30); do
			pgsql -Atc 'SELECT 1' >/dev/null 2>&1 && break
			sleep 1
		done
		pgsql -Atc "SELECT format('DROP TABLE %I;', tablename) FROM pg_tables WHERE schemaname = 'public' AND tablename ~ '^(repl_test_.*|replication_test)$'" 2>/dev/null |
			pgsql >/dev/null 2>&1
		pgsql -c 'DROP ROLE IF EXISTS repl' >/dev/null 2>&1
	fi
	systemctl stop postgresql >/dev/null 2>&1

	# Node 1: the configuration files as recorded
	if [ -d "$pre/conf" ] && [ -d "$D" ]; then
		for f in postgresql.conf postgresql.auto.conf pg_hba.conf; do
			if [ -f "$pre/conf/$f" ]; then
				cat "$pre/conf/$f" > "$D/$f"
			else
				rm -f "$D/$f"
			fi
		done
	fi
	rm -rf "$home/wal_archive"

	# Node 2: the original data directory back. Without a recorded
	# cluster the data directory is empty again on both nodes.
	if [ -f "$pre/data-moved" ] && [ -d "$ORIG" ]; then
		rm -rf "$D"
		mv "$ORIG" "$D" || exit 1
		rm -f "$pre/data-moved"
	elif ! had data; then
		rm -rf "$D"
		install -d -o postgres -g postgres -m 700 "$D" || exit 1
	fi
	restorecon -R "$D" 2>/dev/null

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
else
	# The lab installed the server: remove its files, so that the
	# postgres account owns no file when pkg_restore looks
	systemctl disable --now postgresql >/dev/null 2>&1
	if had home; then
		rm -rf "$D" "$ORIG" "$home/wal_archive" "$home/.pgpass" \
			"$home/.psql_history" "$home/initdb_postgresql.log"
	else
		rm -rf "$home"
	fi
fi
exit 0
} </dev/null
REMOTE

# After the package restore: service state, firewall, the record
cat > "$tmp/after.sh" <<'REMOTE'
{
pre=/var/tmp/replication-02.pre

[ -d "$pre" ] || exit 0

had() {
	grep -qx "$1" "$pre/flags" 2>/dev/null
}

if had server-installed && rpm -q postgresql-server >/dev/null 2>&1; then
	if had enabled; then
		systemctl enable -q postgresql 2>/dev/null
	else
		systemctl disable -q postgresql 2>/dev/null
	fi
	if had active; then
		systemctl start postgresql >/dev/null 2>&1 || exit 1
	fi
fi

fw() {
	firewall-cmd -q --permanent "$@" >/dev/null 2>&1
}
if had fw-service; then fw --add-service=postgresql; else fw --remove-service=postgresql; fi
if had fw-port; then fw --add-port=5432/tcp; else fw --remove-port=5432/tcp; fi
firewall-cmd -q --reload >/dev/null 2>&1

rm -rf "$pre"
exit 0
} </dev/null
REMOTE

rc=0
# Node 2 first, so that nothing replicates from node 1 while it is reset
for n in 2 1; do
	ip=$(get_node_ip "$n")
	if ! run_on_node "$ip" "sudo -n bash -s" < "$tmp/stop.sh" >/dev/null 2>&1; then
		echo "Cleanup of node $n ($ip) failed" >&2
		rc=1
		continue
	fi
	pkg_restore_node "$ip" replication-02 2>"$tmp/err" || {
		echo "Restoring the packages of node $n ($ip) failed:" >&2
		grep -v "^Warning: Permanently added" "$tmp/err" >&2
		# Keep the records of this node for the next reset
		rc=1
		continue
	}
	run_on_node "$ip" "sudo -n bash -s" < "$tmp/after.sh" >/dev/null 2>&1 || {
		echo "Cleanup of node $n ($ip) failed" >&2
		rc=1
	}
done
exit "$rc"
