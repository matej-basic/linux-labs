#!/bin/bash
# clustering-03 grader
source /opt/linux-labs/lib/grading.sh
# load-config.sh is not safe under "set -u"; this grader does not use it
source /opt/linux-labs/lib/load-config.sh
load_lab_config

CONF=/etc/corosync/corosync.conf

grade_begin clustering-03
grade_require_state clustering-03

[ "$NODES_ENABLED" = true ] ||
	grade_abort "Multi-node labs are enabled in the configuration"
[ "$NODE_COUNT" -ge 3 ] 2>/dev/null ||
	grade_abort "The lab configuration has at least 3 nodes"

ips=("$(get_node_ip 1)" "$(get_node_ip 2)" "$(get_node_ip 3)")
node1="${ips[0]}"

on_node() {
	run_on_node "$@" 2>/dev/null
}

# Corosync and Pacemaker are active on every node
services_active() {
	local ip unit
	for ip in "${ips[@]}"; do
		for unit in corosync pacemaker; do
			on_node "$ip" "sudo -n systemctl is-active --quiet $unit" || return 1
		done
	done
}

# Pacemaker on node 1 lists exactly 3 members
three_members() {
	local n
	n=$(on_node "$node1" "sudo -n crm_node -l" | grep -c ' member$')
	[ "$n" -eq 3 ]
}

# Every node is quorate and expects 3 votes
quorate_with_three_votes() {
	local ip out
	for ip in "${ips[@]}"; do
		out=$(on_node "$ip" "sudo -n corosync-quorumtool -s") || true
		echo "$out" | grep -Eq '^Quorate:[[:space:]]+Yes' || return 1
		echo "$out" | grep -Eq '^Expected votes:[[:space:]]+3$' || return 1
	done
}

# Runtime value of a corosync cmap key on a node
cmap_value() {
	on_node "$1" "sudo -n corosync-cmapctl -g $2" | sed -n 's/^.* = //p'
}

# votequorum is the provider and two_node is off, on every node
provider_and_two_node() {
	local ip v
	for ip in "${ips[@]}"; do
		[ "$(cmap_value "$ip" quorum.provider)" = corosync_votequorum ] || return 1
		v=$(cmap_value "$ip" quorum.two_node)
		case "$v" in "" | 0) ;; *) return 1 ;; esac
	done
}

# Option $1 has value $2 in corosync.conf and in the running corosync
# on every node
option_set() {
	local ip
	for ip in "${ips[@]}"; do
		on_node "$ip" "sudo -n grep -Eq '^[[:space:]]*$1:[[:space:]]*$2[[:space:]]*\$' $CONF" || return 1
		[ "$(cmap_value "$ip" "quorum.$1")" = "$2" ] || return 1
	done
}

# A cluster property has one of the accepted values: $1 is its name,
# $2 an ERE of the accepted values. An unset property counts as ok,
# because the default of the properties graded here is the accepted one.
cluster_property_ok() {
	local cfg
	cfg=$(on_node "$node1" "sudo -n cibadmin -Q -o crm_config") || return 1
	if echo "$cfg" | grep -q "name=\"$1\""; then
		echo "$cfg" | grep -Eq "name=\"$1\"[^>]*value=\"($2)\""
	else
		return 0
	fi
}

no_quorum_policy_stop() {
	cluster_property_ok no-quorum-policy stop
}

apache_started() {
	on_node "$node1" "sudo -n crm_resource --locate --resource apache_web" |
		grep -q 'is running on'
}

# Every node sees the same 3-member cluster
same_membership() {
	local ip
	for ip in "${ips[@]}"; do
		on_node "$ip" "sudo -n corosync-quorumtool -s | grep -Eq '^Nodes:[[:space:]]+3\$'" || return 1
	done
}

criterion "Corosync and Pacemaker are active on all three nodes" services_active
criterion "Pacemaker lists all three nodes as members" three_members
criterion "Every node has quorum and expects 3 votes" quorate_with_three_votes
criterion "Quorum provider is votequorum, two_node is not enabled" provider_and_two_node
criterion "wait_for_all is 1 on all nodes" option_set wait_for_all 1
criterion "last_man_standing is 1 on all nodes" option_set last_man_standing 1
criterion "last_man_standing_window is 10000 on all nodes" option_set last_man_standing_window 10000
criterion "Cluster property no-quorum-policy is stop" no_quorum_policy_stop
criterion "Resource apache_web is started" apache_started
criterion "Every node sees the same 3-member cluster" same_membership
grade_end
