#!/bin/bash
# replication-01 cleanup: removes the replication settings, the repl
# account, the replication_test* databases, the option file lines and the
# firewall rules on nodes 1 and 2. mysql-server stays installed. Always
# exits 0.
# No "set -u": load-config.sh reads variables that may be unset.

source /opt/linux-labs/lib/load-config.sh
load_lab_config

[ "$NODES_ENABLED" = "true" ] || exit 0
[ "$NODE_COUNT" -ge 2 ] 2>/dev/null || exit 0

# Remote script, run as root on each node; every step may fail.
read -r -d '' CLEAN <<'REMOTE' || true
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
	restart=yes
fi

rm -f /etc/my.cnf.d/replication.cnf
for f in /etc/my.cnf /etc/my.cnf.d/*.cnf; do
	[ -f "$f" ] || continue
	sed -i -E '/^[[:space:]]*(log[-_]bin|skip[-_]log[-_]bin|disable[-_]log[-_]bin|server[-_]id|relay[-_]log|binlog[-_]format|gtid[-_]mode|enforce[-_]gtid[-_]consistency|log[-_](slave|replica)[-_]updates)[[:space:]]*(=.*)?$/d' "$f"
done

if systemctl is-active --quiet firewalld; then
	firewall-cmd --permanent --remove-service=mysql >/dev/null 2>&1 || true
	firewall-cmd --permanent --remove-port=3306/tcp >/dev/null 2>&1 || true
	firewall-cmd --reload >/dev/null 2>&1 || true
fi

[ "${restart:-}" = yes ] && systemctl restart mysqld </dev/null >/dev/null 2>&1
true
REMOTE

B64=$(printf '%s\n' "$CLEAN" | base64 | tr -d '\n')

# Slave first, so that dropping databases on node 1 cannot reach node 2
for n in 2 1; do
	ip=$(get_node_ip "$n")
	run_on_node "$ip" "sudo -n bash -c \"\$(echo $B64 | base64 -d)\"" </dev/null >/dev/null 2>&1 || true
done
exit 0
