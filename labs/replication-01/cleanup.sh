#!/bin/bash
# replication-01 cleanup: puts nodes 1 and 2 back into the state that the
# first setup.sh run recorded. Where the lab installed MySQL, its data
# and log files go first, so that the mysql account owns no file, and
# then the package set of the first start comes back (lib/packages.sh),
# which removes MySQL with its dependencies and the mysql user and
# group. Where MySQL was there before, the repl account, the
# replication_test* databases and the replication settings go, and its
# option files, persisted variables, boot state and running state come
# back as recorded. The firewall rules for MySQL go back to their
# recorded values. When a node cannot be restored, its records stay for
# the next reset and the exit status is 1.
# No "set -u": load-config.sh reads variables that may be unset.

source /opt/linux-labs/lib/load-config.sh
source /opt/linux-labs/lib/packages.sh
load_lab_config

# Nothing was started without multi-node support
[ "$NODES_ENABLED" = "true" ] || exit 0
[ "$NODE_COUNT" -ge 2 ] 2>/dev/null || exit 0

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Before the package restore: remove the lab's MySQL objects and files,
# stop mysqld
cat > "$tmp/stop.sh" <<'REMOTE'
pre=/var/tmp/replication-01.pre

had() {
	grep -qx "$1" "$pre/flags" 2>/dev/null
}

if had server-installed; then
	# A server from before the lab: remove only what the lab added
	if systemctl is-active --quiet mysqld; then
		mysql --force >/dev/null 2>&1 <<'SQL'
STOP REPLICA;
RESET REPLICA ALL;
RESET PERSIST IF EXISTS server_id;
RESET PERSIST IF EXISTS log_bin;
RESET PERSIST IF EXISTS relay_log;
RESET PERSIST IF EXISTS binlog_format;
SQL
		mysql -N -B 2>/dev/null <<'SQL' | mysql --force >/dev/null 2>&1
SELECT CONCAT('DROP USER ', QUOTE(User), '@', QUOTE(Host), ';') FROM mysql.user WHERE User = 'repl';
SELECT CONCAT('DROP DATABASE `', schema_name, '`;') FROM information_schema.schemata WHERE schema_name LIKE 'replication\_test%';
SQL
	fi
	systemctl stop mysqld </dev/null >/dev/null 2>&1

	# Option files and persisted variables as recorded
	if [ -f "$pre/my.cnf" ]; then
		cp -a "$pre/my.cnf" /etc/my.cnf
	fi
	if [ -d "$pre/my.cnf.d" ]; then
		for f in /etc/my.cnf.d/*; do
			[ -e "$f" ] || continue
			[ -e "$pre/my.cnf.d/$(basename "$f")" ] || rm -f "$f"
		done
		cp -a "$pre/my.cnf.d/." /etc/my.cnf.d/
	else
		rm -f /etc/my.cnf.d/replication.cnf
	fi
	if [ -f "$pre/mysqld-auto.cnf" ]; then
		cp -a "$pre/mysqld-auto.cnf" /var/lib/mysql/mysqld-auto.cnf
	fi
	restorecon -R /etc/my.cnf /etc/my.cnf.d /var/lib/mysql/mysqld-auto.cnf 2>/dev/null
else
	# No record but a server: setup.sh stopped before it looked, so
	# the server is not the lab's
	if [ ! -d "$pre" ] && rpm -q mysql-server >/dev/null 2>&1; then
		exit 0
	fi
	# The lab installed the server: remove its data and log files and
	# the solution's option file, so that the mysql account owns no
	# file when pkg_restore looks
	systemctl disable --now mysqld </dev/null >/dev/null 2>&1
	rm -rf /var/lib/mysql /var/lib/mysql-files /var/lib/mysql-keyring \
		/var/log/mysql /var/run/mysqld
	rm -f /etc/my.cnf.d/replication.cnf
fi
exit 0
REMOTE

# After the package restore: configuration, service, firewall
cat > "$tmp/node.sh" <<'REMOTE'
pre=/var/tmp/replication-01.pre

# setup.sh never recorded this node: nothing to undo
[ -d "$pre" ] || exit 0

had() {
	grep -qx "$1" "$pre/flags" 2>/dev/null
}

if had server-installed; then
	if rpm -q mysql-server >/dev/null 2>&1; then
		if had mysqld-enabled; then
			systemctl enable mysqld </dev/null >/dev/null 2>&1
		else
			systemctl disable mysqld </dev/null >/dev/null 2>&1
		fi
		had mysqld-active && systemctl start mysqld </dev/null >/dev/null 2>&1
	fi
else
	# Configuration files the package removal saved
	rm -f /etc/my.cnf.rpmsave /etc/my.cnf.d/*.rpmsave
fi

fw() {
	firewall-cmd --permanent "$@" </dev/null >/dev/null 2>&1
}
if had fw-mysql; then fw --add-service=mysql; else fw --remove-service=mysql; fi
if had fw-3306; then fw --add-port=3306/tcp; else fw --remove-port=3306/tcp; fi
firewall-cmd --reload </dev/null >/dev/null 2>&1

rm -rf "$pre"
exit 0
REMOTE

rc=0
# Replica first, so that dropping databases on node 1 cannot reach node 2
for n in 2 1; do
	ip=$(get_node_ip "$n")
	if ! run_on_node "$ip" "sudo -n bash -s" < "$tmp/stop.sh" > /dev/null 2>&1; then
		echo "Cleanup of node $n ($ip) failed" >&2
		rc=1
		continue
	fi
	pkg_restore_node "$ip" replication-01 2>"$tmp/err" || {
		echo "Restoring the packages of node $n ($ip) failed:" >&2
		grep -v "^Warning: Permanently added" "$tmp/err" >&2
		# Keep the records of this node for the next reset
		rc=1
		continue
	}
	run_on_node "$ip" "sudo -n bash -s" < "$tmp/node.sh" > /dev/null 2>&1 || {
		echo "Cleanup of node $n ($ip) failed" >&2
		rc=1
	}
done
exit "$rc"
