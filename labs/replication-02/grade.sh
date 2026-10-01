#!/bin/bash
# replication-02 grader
# shellcheck source=/dev/null
source /opt/linux-labs/lib/load-config.sh
source /opt/linux-labs/lib/grading.sh
load_lab_config

ARCHIVE_DIR=/var/lib/pgsql/wal_archive

grade_begin replication-02
grade_require_state replication-02

if [[ "$NODES_ENABLED" != "true" ]]; then
	grade_abort "Multi-node labs are enabled in the configuration"
fi
if [[ "$NODE_COUNT" -lt 2 ]]; then
	grade_abort "At least 2 nodes are configured"
fi

PRIMARY_IP=$(get_node_ip 1)
STANDBY_IP=$(get_node_ip 2)

for ip in "$PRIMARY_IP" "$STANDBY_IP"; do
	test_node_connectivity "$ip" >/dev/null 2>&1 || grade_abort "Node $ip is reachable over SSH"
done

# psql_on <ip> <sql>: run SQL as postgres on a node, print bare values
psql_on() {
	run_on_node "$1" "cd /tmp && sudo -n -u postgres psql -X -Atq -c $(printf '%q' "$2")" 2>/dev/null
}

service_active() {
	run_on_node "$1" "systemctl is-active --quiet postgresql" 2>/dev/null
}

archiving_enabled() {
	local mode cmd
	mode=$(psql_on "$PRIMARY_IP" "SHOW archive_mode") || return 1
	cmd=$(psql_on "$PRIMARY_IP" "SHOW archive_command") || return 1
	[[ "$mode" == "on" || "$mode" == "always" ]] || return 1
	[[ -n "$cmd" && "$cmd" != "(disabled)" ]]
}

# Force a WAL switch on the primary and wait for the segment to arrive in
# the archive directory.
segments_archived() {
	local cmd n
	cmd=$(psql_on "$PRIMARY_IP" "SHOW archive_command") || return 1
	[[ "$cmd" == *"$ARCHIVE_DIR"* ]] || return 1
	psql_on "$PRIMARY_IP" "SELECT pg_create_restore_point('lab-grade'); SELECT pg_switch_wal();" >/dev/null || return 1
	for _ in $(seq 1 20); do
		n=$(run_on_node "$PRIMARY_IP" "sudo -n ls -A $ARCHIVE_DIR 2>/dev/null | wc -l" 2>/dev/null)
		[ "${n:-0}" -ge 1 ] && return 0
		sleep 1
	done
	return 1
}

repl_role_ok() {
	[ "$(psql_on "$PRIMARY_IP" "SELECT count(*) FROM pg_roles WHERE rolname = 'repl' AND rolcanlogin AND rolreplication")" = "1" ]
}

standby_in_recovery() {
	[ "$(psql_on "$STANDBY_IP" "SELECT pg_is_in_recovery()")" = "t" ]
}

standby_streaming() {
	local n
	n=$(psql_on "$STANDBY_IP" "SELECT count(*) FROM pg_stat_wal_receiver WHERE status = 'streaming' AND conninfo LIKE '%user=repl%'") || return 1
	[ "${n:-0}" -ge 1 ]
}

primary_sees_standby() {
	local n
	n=$(psql_on "$PRIMARY_IP" "SELECT count(*) FROM pg_stat_replication WHERE usename = 'repl' AND state = 'streaming'") || return 1
	[ "${n:-0}" -ge 1 ]
}

# Write a row on the primary, wait for it on the standby, drop the table
data_replicates() {
	local t="repl_test_$$" n rc=1
	if psql_on "$PRIMARY_IP" "CREATE TABLE $t (id int); INSERT INTO $t VALUES (42);" >/dev/null; then
		for _ in $(seq 1 15); do
			n=$(psql_on "$STANDBY_IP" "SELECT count(*) FROM $t")
			if [ "$n" = "1" ]; then rc=0; break; fi
			sleep 1
		done
	fi
	psql_on "$PRIMARY_IP" "DROP TABLE IF EXISTS $t" >/dev/null
	return "$rc"
}

criterion "PostgreSQL is running on the primary $PRIMARY_IP" service_active "$PRIMARY_IP"
criterion "PostgreSQL is running on the standby $STANDBY_IP" service_active "$STANDBY_IP"
criterion "WAL archiving is enabled on the primary" archiving_enabled
criterion "WAL segments are archived to $ARCHIVE_DIR" segments_archived
criterion "Role repl can log in and replicate on the primary" repl_role_ok
criterion "The standby is in recovery mode" standby_in_recovery
criterion "The standby streams WAL from the primary as role repl" standby_streaming
criterion "The primary shows a streaming client of role repl" primary_sees_standby
criterion "Data written on the primary appears on the standby" data_replicates
grade_end
