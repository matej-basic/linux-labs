#!/bin/bash
# clustering-02 setup: put the clustering-01 cluster into the state
# "no fence agent, no fence devices, fencing disabled".
source /opt/linux-labs/lib/load-config.sh
load_lab_config
set -eu

STATE_DIR=/opt/linux-labs/state
STATE_FILE=$STATE_DIR/clustering-02

if [ "$NODES_ENABLED" != "true" ]; then
	echo "Error: multi-node labs are not enabled. Run: sudo labctl configure interactive" >&2
	exit 1
fi
if [ "$NODE_COUNT" -lt 3 ]; then
	echo "Error: this lab needs 3 nodes, NODE_COUNT is $NODE_COUNT. Run: sudo labctl configure set NODE_COUNT 3" >&2
	exit 1
fi

NODE1_IP=$(get_node_ip 1)
NODE2_IP=$(get_node_ip 2)
NODE3_IP=$(get_node_ip 3)

for ip in "$NODE1_IP" "$NODE2_IP" "$NODE3_IP"; do
	if ! test_node_connectivity "$ip" >/dev/null 2>&1; then
		echo "Error: cannot reach node $ip over SSH. Check the lab configuration." >&2
		exit 1
	fi
done

if ! run_on_node "$NODE1_IP" "sudo cibadmin -Q --xpath \"//primitive[@id='apache_web']\"" >/dev/null 2>&1; then
	echo "Error: no running Pacemaker cluster with the resource apache_web on $NODE1_IP. Complete clustering-01 first." >&2
	exit 1
fi

# Remove fence devices a previous run or the solution left behind
for id in stonith-node1 stonith-node2 stonith-node3; do
	run_on_node "$NODE1_IP" "sudo pcs stonith delete $id" >/dev/null 2>&1 || true
done
if ! run_on_node "$NODE1_IP" "sudo pcs property set stonith-enabled=false" >/dev/null 2>&1; then
	echo "Error: cannot set stonith-enabled=false on $NODE1_IP." >&2
	exit 1
fi

# Remove the fence agents (unless another package needs them)
REMOVE_FENCE="for p in fence-agents-all fence-agents-virsh; do if rpm -q \$p >/dev/null 2>&1 && ! rpm -q --whatrequires \$p >/dev/null 2>&1; then sudo dnf -y remove \$p; fi; done"
for ip in "$NODE1_IP" "$NODE2_IP" "$NODE3_IP"; do
	run_on_node "$ip" "$REMOVE_FENCE" >/dev/null 2>&1 || true
done

mkdir -p "$STATE_DIR"
printf '%s\n%s\n%s\n' "$NODE1_IP" "$NODE2_IP" "$NODE3_IP" >"$STATE_FILE"
chmod 0644 "$STATE_FILE"
exit 0
