#!/bin/bash
# replication-03 cleanup: removes the replication setup, the replication
# account, the test databases and the firewall rule from the three nodes.
# Nodes where setup.sh installed mysql-server get the package and its data
# removed again; on other nodes the packaged configuration is restored.
# No "set -u": load-config.sh reads variables that may be unset.

source /opt/linux-labs/lib/load-config.sh
load_lab_config

rm -f /opt/linux-labs/state/replication-03

# Nothing was started without multi-node support
[ "$NODES_ENABLED" = "true" ] || exit 0
[ "$NODE_COUNT" -ge 3 ] 2>/dev/null || exit 0

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

cat > "$tmp/node.sh" <<'REMOTE'
cnf=/etc/my.cnf.d/mysql-server.cnf
bak=/var/tmp/replication-03.mysql-server.cnf
marker=/var/tmp/replication-03.installed
seen=/var/tmp/replication-03.service

# Local statements are not binary-logged, so nothing travels to the
# other nodes while they are being cleaned up
q() {
	printf '%s;\n' "$1" | mysql -u root -N 2>/dev/null
}

if systemctl is-active --quiet mysqld; then
	q "STOP REPLICA"
	q "RESET REPLICA ALL"
	q "SET sql_log_bin=0; DROP USER IF EXISTS 'repl'@'%'"
	for db in $(q "SELECT schema_name FROM information_schema.schemata WHERE LEFT(schema_name, 7) = 'lab_mm_' OR schema_name = 'ring_test'"); do
		q "SET sql_log_bin=0; DROP DATABASE IF EXISTS \`$db\`"
	done
fi

if [ -f "$marker" ]; then
	systemctl disable --now mysqld </dev/null >/dev/null 2>&1
	dnf -y remove mysql-server </dev/null >/dev/null 2>&1
	find /var/lib/mysql -mindepth 1 -delete 2>/dev/null
	rm -f "$cnf.rpmsave" "$cnf" /var/log/mysql/mysqld.log /etc/my.cnf.d/replication.cnf
	# The package could not remove its directories while they held files
	rmdir /var/lib/mysql /var/log/mysql /etc/my.cnf.d 2>/dev/null
	rm -f "$marker" "$bak"
else
	rm -f /etc/my.cnf.d/replication.cnf
	[ -f "$bak" ] && cp -p "$bak" "$cnf"
	rm -f "$bak"
	if systemctl try-restart mysqld </dev/null >/dev/null 2>&1; then
		# Binary logs of the solution's log-bin name, unused after the restart
		rm -f /var/lib/mysql/mysql-bin.[0-9]* /var/lib/mysql/mysql-bin.index
	fi
	# Back to the service state found by the first setup.sh run
	if [ -f "$seen" ]; then
		grep -qx enabled "$seen" || systemctl disable mysqld </dev/null >/dev/null 2>&1
		grep -qx active "$seen" || systemctl stop mysqld </dev/null >/dev/null 2>&1
	fi
	rm -f "$seen"
fi

firewall-cmd --permanent --remove-service=mysql >/dev/null 2>&1
firewall-cmd --permanent --remove-port=3306/tcp >/dev/null 2>&1
firewall-cmd --reload >/dev/null 2>&1
exit 0
REMOTE

rc=0
for n in 1 2 3; do
	ip=$(get_node_ip "$n")
	run_on_node "$ip" "sudo -n bash -s" < "$tmp/node.sh" > /dev/null 2>&1 || {
		echo "Cleanup of node $n ($ip) failed" >&2
		rc=1
	}
done
exit "$rc"
