#!/bin/bash
# replication-03 grader
source /opt/linux-labs/lib/load-config.sh
source /opt/linux-labs/lib/grading.sh
load_lab_config

grade_begin replication-03
grade_require_state replication-03

[ "$NODES_ENABLED" = "true" ] || grade_abort "Multi-node labs are enabled in the configuration"
[ "$NODE_COUNT" -ge 3 ] 2>/dev/null || grade_abort "The configuration defines at least 3 nodes"

NODE1_IP=$(get_node_ip 1)
NODE2_IP=$(get_node_ip 2)
NODE3_IP=$(get_node_ip 3)

for ip in "$NODE1_IP" "$NODE2_IP" "$NODE3_IP"; do
	test_node_connectivity "$ip" >/dev/null 2>&1 || grade_abort "All three nodes are reachable over SSH"
done

# sql_on <ip> <statement>: run SQL as MySQL root on a node, batch output
# without column names. The statement goes through stdin, so it may
# contain any quotes.
sql_on() {
	printf '%s\n' "$2" | run_on_node "$1" "sudo -n mysql -u root -N -B"
}

mysqld_running() {
	local ip
	for ip in "$NODE1_IP" "$NODE2_IP" "$NODE3_IP"; do
		run_on_node "$ip" "sudo -n systemctl is-enabled mysqld && sudo -n systemctl is-active mysqld" || return 1
	done
}

binlog_enabled() {
	local ip
	for ip in "$NODE1_IP" "$NODE2_IP" "$NODE3_IP"; do
		[ "$(sql_on "$ip" "SELECT @@log_bin")" = "1" ] || return 1
	done
}

# Running server IDs: three numbers, all different, none zero
server_ids_differ() {
	local a b c
	a=$(sql_on "$NODE1_IP" "SELECT @@server_id") || return 1
	b=$(sql_on "$NODE2_IP" "SELECT @@server_id") || return 1
	c=$(sql_on "$NODE3_IP" "SELECT @@server_id") || return 1
	case "$a$b$c" in *[!0-9]* | "") return 1 ;; esac
	[ "$a" -gt 0 ] && [ "$b" -gt 0 ] && [ "$c" -gt 0 ] || return 1
	[ "$a" != "$b" ] && [ "$a" != "$c" ] && [ "$b" != "$c" ]
}

# configured_server_id <ip>: the server ID that a restart of mysqld would
# use. SET PERSIST (mysqld-auto.cnf) wins over the option files, and the
# last server-id line of the option files wins over earlier ones.
configured_server_id() {
	local v
	v=$(run_on_node "$1" "sudo -n cat /var/lib/mysql/mysqld-auto.cnf 2>/dev/null" |
		grep -Eo '"server_id" *: *\{ *"Value" *: *"[0-9]+"' | grep -Eo '[0-9]+"$' | tr -d '"')
	if [ -z "$v" ]; then
		v=$(run_on_node "$1" "sudo -n cat /etc/my.cnf /etc/my.cnf.d/*.cnf 2>/dev/null" |
			grep -Ei '^[[:space:]]*server[-_]id[[:space:]]*=' | tail -n 1 |
			sed 's/^[^=]*=[[:space:]]*//; s/[[:space:]]*#.*//; s/[[:space:]]*$//')
	fi
	printf '%s' "$v"
}

server_ids_persistent() {
	local ip cfg run
	for ip in "$NODE1_IP" "$NODE2_IP" "$NODE3_IP"; do
		cfg=$(configured_server_id "$ip")
		run=$(sql_on "$ip" "SELECT @@server_id") || return 1
		[ -n "$cfg" ] && [ "$cfg" = "$run" ] || return 1
	done
}

# replicates_from <replica ip> <source ip>: the default channel points at
# the source IP and both threads are on. Retries for a few seconds,
# because a replica that has just been started shows CONNECTING.
replicates_from() {
	local row want
	want=$(printf '%s\t%s\t%s' "$2" ON ON)
	for _ in 1 2 3 4 5; do
		row=$(sql_on "$1" "SELECT c.HOST, s.SERVICE_STATE, a.SERVICE_STATE FROM performance_schema.replication_connection_configuration c JOIN performance_schema.replication_connection_status s ON s.CHANNEL_NAME = c.CHANNEL_NAME JOIN performance_schema.replication_applier_status a ON a.CHANNEL_NAME = c.CHANNEL_NAME WHERE c.CHANNEL_NAME = ''")
		[ "$row" = "$want" ] && return 0
		sleep 1
	done
	return 1
}

# change_reaches <origin ip> <other ip> <other ip>: a database created on
# the origin shows up on both other nodes within 12 seconds each. The
# origin drops it again, which replicates the same way.
change_reaches() {
	local origin=$1 db other found bad=0
	shift
	db="lab_mm_${RANDOM}_$$"
	sql_on "$origin" "CREATE DATABASE $db" >/dev/null || return 1
	for other in "$@"; do
		found=0
		for _ in $(seq 12); do
			if [ "$(sql_on "$other" "SELECT schema_name FROM information_schema.schemata WHERE schema_name = '$db'")" = "$db" ]; then
				found=1
				break
			fi
			sleep 1
		done
		[ "$found" = 1 ] || bad=1
	done
	sql_on "$origin" "DROP DATABASE IF EXISTS $db" >/dev/null
	return "$bad"
}

criterion "mysqld is enabled and running on all three nodes" mysqld_running
criterion "Binary logging is enabled on all three nodes" binlog_enabled
criterion "The three nodes have three different server IDs" server_ids_differ
criterion "Each server ID is set in the MySQL configuration" server_ids_persistent
criterion "Node 2 replicates from node 1, both threads running" replicates_from "$NODE2_IP" "$NODE1_IP"
criterion "Node 3 replicates from node 2, both threads running" replicates_from "$NODE3_IP" "$NODE2_IP"
criterion "Node 1 replicates from node 3, both threads running" replicates_from "$NODE1_IP" "$NODE3_IP"
criterion "A change made on node 1 reaches nodes 2 and 3" change_reaches "$NODE1_IP" "$NODE2_IP" "$NODE3_IP"
criterion "A change made on node 2 reaches nodes 1 and 3" change_reaches "$NODE2_IP" "$NODE1_IP" "$NODE3_IP"
criterion "A change made on node 3 reaches nodes 1 and 2" change_reaches "$NODE3_IP" "$NODE1_IP" "$NODE2_IP"
grade_end
