#!/bin/bash
# replication-01 grader
source /opt/linux-labs/lib/load-config.sh
source /opt/linux-labs/lib/grading.sh
load_lab_config

grade_begin replication-01

[ "$NODES_ENABLED" = "true" ] || grade_abort "Multi-node labs are enabled in the configuration"
[ "$NODE_COUNT" -ge 2 ] 2>/dev/null || grade_abort "The configuration defines at least 2 nodes"

NODE1_IP=$(get_node_ip 1)
NODE2_IP=$(get_node_ip 2)

for ip in "$NODE1_IP" "$NODE2_IP"; do
	test_node_connectivity "$ip" >/dev/null 2>&1 || grade_abort "Nodes 1 and 2 are reachable over SSH"
done

# sql <ip> <statements>: run SQL as MySQL root on a node, tab-separated
# output without headers. Statements go in on standard input.
sql() {
	printf '%s\n' "$2" | run_on_node "$1" "sudo -n mysql -N -B" 2>/dev/null
}

service_ok() {
	run_on_node "$1" "sudo -n systemctl is-enabled mysqld && sudo -n systemctl is-active mysqld"
}

binlog_on() {
	[ "$(sql "$NODE1_IP" 'SELECT @@log_bin;')" = 1 ]
}

server_ids_differ() {
	local a b
	a=$(sql "$NODE1_IP" 'SELECT @@server_id;')
	b=$(sql "$NODE2_IP" 'SELECT @@server_id;')
	[ -n "$a" ] && [ -n "$b" ] && [ "$a" != "$b" ]
}

# The server ID of node 2 comes from an option file or from SET PERSIST,
# so it is still set after a restart of mysqld.
replica_id_persistent() {
	run_on_node "$NODE2_IP" "sudo -n mysqld --print-defaults 2>/dev/null" | grep -Eq -- '--server[-_]id=[0-9]+' && return 0
	[ "$(sql "$NODE2_IP" "SELECT COUNT(*) FROM performance_schema.persisted_variables WHERE variable_name = 'server_id';")" -ge 1 ]
}

repl_account() {
	[ "$(sql "$NODE1_IP" "SELECT COUNT(*) FROM mysql.user WHERE User = 'repl' AND Repl_slave_priv = 'Y';")" -ge 1 ]
}

# replica_field <name>: a field of SHOW REPLICA STATUS on node 2. Not
# through sql(): with -N the vertical output has no field names.
replica_field() {
	printf '%s\n' 'SHOW REPLICA STATUS\G' |
		run_on_node "$NODE2_IP" "sudo -n mysql -B" 2>/dev/null |
		sed -n "s/^ *$1: //p" | head -n 1
}

replicates_from_node1() {
	[ "$(replica_field Source_Host)" = "$NODE1_IP" ] && [ "$(replica_field Source_User)" = repl ]
}

io_running() {
	[ "$(replica_field Replica_IO_Running)" = Yes ]
}

sql_running() {
	[ "$(replica_field Replica_SQL_Running)" = Yes ]
}

# A database with a table and a row is created on node 1 and must show
# up with its row on node 2 within 15 seconds. It is dropped afterwards.
data_replicates() {
	local db="replication_test_$$" got=""
	sql "$NODE1_IP" "CREATE DATABASE $db; CREATE TABLE $db.t (id INT PRIMARY KEY, v VARCHAR(20)); INSERT INTO $db.t VALUES (1, 'grade');" >/dev/null || {
		sql "$NODE1_IP" "DROP DATABASE IF EXISTS $db;" >/dev/null
		return 1
	}
	for _ in $(seq 15); do
		got=$(sql "$NODE2_IP" "SELECT v FROM $db.t WHERE id = 1;")
		[ "$got" = grade ] && break
		sleep 1
	done
	sql "$NODE1_IP" "DROP DATABASE IF EXISTS $db;" >/dev/null
	[ "$got" = grade ]
}

criterion "MySQL is enabled and running on node 1" service_ok "$NODE1_IP"
criterion "MySQL is enabled and running on node 2" service_ok "$NODE2_IP"
criterion "Binary logging is enabled on node 1" binlog_on
criterion "Node 1 and node 2 have different server IDs" server_ids_differ
criterion "The server ID of node 2 is set persistently" replica_id_persistent
criterion "Account repl with REPLICATION SLAVE exists on node 1" repl_account
criterion "Node 2 replicates from $NODE1_IP as repl" replicates_from_node1
criterion "The replication I/O thread on node 2 is running" io_running
criterion "The replication SQL thread on node 2 is running" sql_running
criterion "Data written on node 1 appears on node 2" data_replicates
grade_end
