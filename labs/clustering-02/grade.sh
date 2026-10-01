#!/bin/bash
# clustering-02 grader
source /opt/linux-labs/lib/grading.sh
source /opt/linux-labs/lib/load-config.sh

STATE_FILE=/opt/linux-labs/state/clustering-02

grade_begin clustering-02
grade_require_state clustering-02 "$STATE_FILE"

load_lab_config
[ "$NODES_ENABLED" = "true" ] || grade_abort "Multi-node labs are enabled in the configuration"
[ "$NODE_COUNT" -ge 3 ] 2>/dev/null || grade_abort "The configuration has at least 3 nodes"

NODE1_IP=$(get_node_ip 1)
NODE2_IP=$(get_node_ip 2)
NODE3_IP=$(get_node_ip 3)

# Run a command on node 1, where the cluster is queried
n1() {
	run_on_node "$NODE1_IP" "$1"
}

# Succeeds if the CIB on node 1 matches the XPath expression
cib_has() {
	n1 "sudo -n cibadmin -Q --xpath \"$1\""
}

# Print the crm_mon XML status of the cluster
cluster_xml() {
	n1 "sudo -n crm_mon -1 --output-as=xml --include=all 2>/dev/null || sudo -n crm_mon -1 --output-as=xml 2>/dev/null || sudo -n crm_mon -1 -X 2>/dev/null"
}

agent_installed() {
	run_on_node "$1" "test -x /usr/sbin/fence_virsh"
}

device_uses_agent() {
	cib_has "//primitive[@id='$1' and @class='stonith' and @type='fence_virsh']"
}

# device_restricted <device> <node ip>: the host list is the node's name
device_restricted() {
	local name
	name=$(run_on_node "$2" "sudo -n crm_node -n") || return 1
	name=$(printf '%s' "$name" | tr -d '[:space:]')
	[ -n "$name" ] || return 1
	cib_has "//primitive[@id='$1']//nvpair[@name='pcmk_host_list' and @value='$name']"
}

fencing_enabled() {
	local v
	v=$(n1 "sudo -n cibadmin -Q >/dev/null 2>&1 && { sudo -n crm_attribute --type crm_config --name stonith-enabled --query --quiet 2>/dev/null || echo default; }") || return 1
	v=$(printf '%s' "$v" | tr -d '[:space:]')
	case "$v" in
		"") return 1 ;;
		false|no|off|0) return 1 ;;
	esac
	return 0
}

has_quorum() {
	n1 "sudo -n corosync-quorumtool -s"
}

all_nodes_online() {
	local x
	x=$(cluster_xml) || return 1
	[ "$(printf '%s\n' "$x" | grep -c '<node .*online="true"')" -ge 3 ] || return 1
	! printf '%s\n' "$x" | grep -q '<node .*online="false"'
}

apache_started() {
	local line
	line=$(cluster_xml | grep '<resource id="apache_web"' | head -n 1)
	case "$line" in
		*'role="Started"'*) ;;
		*) return 1 ;;
	esac
	case "$line" in
		*'active="true"'*) ;;
		*) return 1 ;;
	esac
	case "$line" in
		*'failed="false"'*) return 0 ;;
	esac
	return 1
}

no_failed_actions() {
	local x
	x=$(cluster_xml) || return 1
	[ -n "$x" ] || return 1
	! printf '%s\n' "$x" | grep '<failure ' | grep -qv 'op_key="stonith-node[123]_'
}

criterion "fence_virsh is installed on node 1 ($NODE1_IP)" agent_installed "$NODE1_IP"
criterion "fence_virsh is installed on node 2 ($NODE2_IP)" agent_installed "$NODE2_IP"
criterion "fence_virsh is installed on node 3 ($NODE3_IP)" agent_installed "$NODE3_IP"
criterion "Fence device stonith-node1 uses fence_virsh" device_uses_agent stonith-node1
criterion "Fence device stonith-node2 uses fence_virsh" device_uses_agent stonith-node2
criterion "Fence device stonith-node3 uses fence_virsh" device_uses_agent stonith-node3
criterion "Device stonith-node1 is restricted to node 1" device_restricted stonith-node1 "$NODE1_IP"
criterion "Device stonith-node2 is restricted to node 2" device_restricted stonith-node2 "$NODE2_IP"
criterion "Device stonith-node3 is restricted to node 3" device_restricted stonith-node3 "$NODE3_IP"
criterion "Fencing is enabled in the cluster properties" fencing_enabled
criterion "The cluster has quorum" has_quorum
criterion "All three nodes are online" all_nodes_online
criterion "Resource apache_web is started" apache_started
criterion "No failed actions except for the fence devices" no_failed_actions
grade_end
