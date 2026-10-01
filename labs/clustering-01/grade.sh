#!/bin/bash
# clustering-01 grader
source /opt/linux-labs/lib/load-config.sh
source /opt/linux-labs/lib/grading.sh

STATE_FILE=/opt/linux-labs/state/clustering-01

grade_begin clustering-01
grade_require_state clustering-01 "$STATE_FILE"
[ "${NODES_ENABLED:-}" = true ] ||
	grade_abort "Multi-node labs are enabled in the configuration"
[ "${NODE_COUNT:-0}" -ge 3 ] 2>/dev/null ||
	grade_abort "NODE_COUNT is at least 3 in the configuration"

NODE1_IP=$(get_node_ip 1)
NODE2_IP=$(get_node_ip 2)
NODE3_IP=$(get_node_ip 3)

# service_up <ip> <unit>: the unit is enabled at boot and running
service_up() {
	run_on_node "$1" "sudo -n systemctl is-enabled --quiet $2 && sudo -n systemctl is-active --quiet $2"
}

# is_member <ip>: the node, by host name, is a member in node 1's view
is_member() {
	local h
	h=$(run_on_node "$1" "uname -n") || return 1
	h="${h%%.*}"
	run_on_node "$NODE1_IP" "sudo -n crm_node -l" |
		awk -v h="$h" '{ n = $2; sub(/\..*/, "", n) } n == h && $3 == "member" { f = 1 } END { exit !f }'
}

# quorum_field <pattern> <value>: corosync-quorumtool shows the value
quorum_field() {
	run_on_node "$NODE1_IP" "sudo -n corosync-quorumtool -s" |
		awk -v p="$1" -v v="$2" '$0 ~ p { if ($NF == v) f = 1 } END { exit !f }'
}

cluster_name_is() {
	run_on_node "$NODE1_IP" "sudo -n corosync-cmapctl -g totem.cluster_name" |
		awk -v n="$1" '{ if ($NF == n) f = 1 } END { exit !f }'
}

stonith_disabled() {
	[ "$(run_on_node "$NODE1_IP" "sudo -n crm_attribute -t crm_config -n stonith-enabled -G -q")" = false ]
}

# httpd_ready <ip>: httpd installed, not enabled at boot
httpd_ready() {
	run_on_node "$1" "rpm -q httpd >/dev/null && ! sudo -n systemctl is-enabled --quiet httpd"
}

# page_ok <ip>: the page names the cluster and the host
page_ok() {
	# shellcheck disable=SC2016 # the command is meant to expand on the node
	run_on_node "$1" 'h=$(uname -n); h=${h%%.*}; grep -qF "HA Cluster" /var/www/html/index.html && grep -qF "$h" /var/www/html/index.html'
}

resource_defined() {
	run_on_node "$NODE1_IP" "sudo -n crm_resource -r apache_web -q" |
		grep 'class="ocf"' | grep 'provider="heartbeat"' | grep -q 'type="apache"'
}

resource_started() {
	run_on_node "$NODE1_IP" "sudo -n crm_mon -1 -r" | grep -Eq 'apache_web.*Started'
}

httpd_on_one_node() {
	local ip count=0
	for ip in "$NODE1_IP" "$NODE2_IP" "$NODE3_IP"; do
		if run_on_node "$ip" "pgrep -x httpd"; then
			count=$((count + 1))
		fi
	done
	[ "$count" -eq 1 ]
}

n=0
for ip in "$NODE1_IP" "$NODE2_IP" "$NODE3_IP"; do
	n=$((n + 1))
	criterion "corosync is enabled and running on node $n ($ip)" service_up "$ip" corosync
	criterion "pacemaker is enabled and running on node $n ($ip)" service_up "$ip" pacemaker
done

criterion "Cluster is named ha_cluster" cluster_name_is ha_cluster

n=0
for ip in "$NODE1_IP" "$NODE2_IP" "$NODE3_IP"; do
	n=$((n + 1))
	criterion "Node $n ($ip) is an online cluster member" is_member "$ip"
done

criterion "Cluster has quorum" quorum_field '^Quorate:' Yes
criterion "Cluster has 3 votes" quorum_field '^Total votes:' 3
criterion "Quorum is 2 votes" quorum_field '^Quorum:' 2
criterion "STONITH is disabled" stonith_disabled

n=0
for ip in "$NODE1_IP" "$NODE2_IP" "$NODE3_IP"; do
	n=$((n + 1))
	criterion "httpd is installed, not enabled at boot, node $n" httpd_ready "$ip"
	criterion "Node $n has an HA Cluster page naming its host" page_ok "$ip"
done

criterion "Resource apache_web uses ocf:heartbeat:apache" resource_defined
criterion "Resource apache_web is started" resource_started
criterion "httpd runs on exactly one node" httpd_on_one_node

grade_end
