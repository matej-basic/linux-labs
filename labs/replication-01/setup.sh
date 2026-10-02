#!/bin/bash
# replication-01 setup: puts nodes 1 and 2 into the starting state (MySQL
# installed and running, no replication account or settings, port 3306
# closed). Prints nothing on success. Nothing on the workstation changes.
#
# The first run records each node's package set (lib/packages.sh), so
# that cleanup.sh removes MySQL again where the lab installed it. It also
# records in /var/tmp/replication-01.pre on the node whether mysql-server
# was there, its boot and running state, its option files and persisted
# variables, and the firewall rules for MySQL, so that cleanup.sh puts
# back a server that existed before the lab.
# No "set -u": load-config.sh reads variables that may be unset.
set -e

source /opt/linux-labs/lib/load-config.sh
source /opt/linux-labs/lib/packages.sh
load_lab_config

if [ "$NODES_ENABLED" != "true" ]; then
	echo "replication-01 needs multi-node labs: run 'sudo labctl configure interactive' and enable them" >&2
	exit 1
fi
if [ "$NODE_COUNT" -lt 2 ] 2>/dev/null; then
	echo "replication-01 needs 2 nodes, NODE_COUNT is $NODE_COUNT: run 'sudo labctl configure set NODE_COUNT 2'" >&2
	exit 1
fi

for n in 1 2; do
	ip=$(get_node_ip "$n")
	if ! test_node_connectivity "$ip" >/dev/null; then
		echo "Cannot reach node $n ($ip) over SSH as $SSH_USER" >&2
		exit 1
	fi
done

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Remote script, run as root on each node through "bash -s", so every
# command that could read stdin gets /dev/null instead of the script. It
# installs and starts MySQL, then removes what the lab and its solution
# create: replication settings, the repl account, replication_test*
# databases, the option file lines for binary log, server ID and relay
# log, and the firewall rules for MySQL. The MySQL root login must work
# without a password prompt (socket authentication or /root/.my.cnf).
cat > "$tmp/node.sh" <<'REMOTE'
pre=/var/tmp/replication-01.pre

wait_mysql() {
	local i
	for i in $(seq 60); do
		mysql -e 'SELECT 1' </dev/null >/dev/null 2>&1 && return 0
		sleep 1
	done
	return 1
}

# First run only: the state of a server that was there before the lab
if [ ! -d "$pre" ]; then
	rm -rf "$pre.tmp"
	mkdir -m 0700 "$pre.tmp" || exit 1
	{
		if rpm -q mysql-server >/dev/null 2>&1; then
			echo server-installed
			systemctl is-enabled --quiet mysqld 2>/dev/null && echo mysqld-enabled
			systemctl is-active --quiet mysqld 2>/dev/null && echo mysqld-active
		fi
		firewall-cmd --permanent --query-service=mysql </dev/null >/dev/null 2>&1 && echo fw-mysql
		firewall-cmd --permanent --query-port=3306/tcp </dev/null >/dev/null 2>&1 && echo fw-3306
	} > "$pre.tmp/flags"
	if grep -qx server-installed "$pre.tmp/flags"; then
		[ -f /etc/my.cnf ] && { cp -a /etc/my.cnf "$pre.tmp/my.cnf" || exit 1; }
		if [ -d /etc/my.cnf.d ]; then
			cp -a /etc/my.cnf.d "$pre.tmp/my.cnf.d" || exit 1
		fi
		if [ -f /var/lib/mysql/mysqld-auto.cnf ]; then
			cp -a /var/lib/mysql/mysqld-auto.cnf "$pre.tmp/mysqld-auto.cnf" || exit 1
		fi
	fi
	mv "$pre.tmp" "$pre" || exit 1
fi

if ! rpm -q mysql-server >/dev/null 2>&1; then
	dnf -y install mysql-server </dev/null >/dev/null 2>&1 || {
		echo "installing mysql-server failed (is mariadb-server installed?)" >&2
		exit 1
	}
fi
systemctl enable --now mysqld </dev/null >/dev/null 2>&1 || {
	echo "mysqld does not start" >&2
	exit 1
}
wait_mysql || {
	echo "cannot log in to MySQL as root without a password (use /root/.my.cnf)" >&2
	exit 1
}

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

rm -f /etc/my.cnf.d/replication.cnf
for f in /etc/my.cnf /etc/my.cnf.d/*.cnf; do
	[ -f "$f" ] || continue
	sed -i -E '/^[[:space:]]*(log[-_]bin|skip[-_]log[-_]bin|disable[-_]log[-_]bin|server[-_]id|relay[-_]log|binlog[-_]format|gtid[-_]mode|enforce[-_]gtid[-_]consistency|log[-_](slave|replica)[-_]updates)[[:space:]]*(=.*)?$/d' "$f"
done

if systemctl is-active --quiet firewalld; then
	firewall-cmd --permanent --remove-service=mysql </dev/null >/dev/null 2>&1 || true
	firewall-cmd --permanent --remove-port=3306/tcp </dev/null >/dev/null 2>&1 || true
	firewall-cmd --reload </dev/null >/dev/null 2>&1 || true
fi

systemctl restart mysqld </dev/null >/dev/null 2>&1
wait_mysql || {
	echo "mysqld does not come back after the restart" >&2
	exit 1
}
exit 0
REMOTE

# Replica first, so that cleaning node 1 cannot reach node 2
for n in 2 1; do
	ip=$(get_node_ip "$n")
	if ! pkg_snapshot_node "$ip" replication-01 > "$tmp/out" 2>&1; then
		echo "Recording the packages of node $n ($ip) failed:" >&2
		cat "$tmp/out" >&2
		exit 1
	fi
	if ! run_on_node "$ip" "sudo -n bash -s" < "$tmp/node.sh" > "$tmp/out" 2>&1; then
		echo "Preparing node $n ($ip) failed:" >&2
		cat "$tmp/out" >&2
		exit 1
	fi
done
