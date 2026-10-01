#!/bin/bash
# clustering-02 cleanup: back to the end state of clustering-01 (no fence
# devices, fencing disabled, no fence agents).
STATE_FILE=/opt/linux-labs/state/clustering-02

source /opt/linux-labs/lib/load-config.sh
load_lab_config

if [ "$NODES_ENABLED" = "true" ] && [ "$NODE_COUNT" -ge 3 ] 2>/dev/null; then
	NODE1_IP=$(get_node_ip 1)
	NODE2_IP=$(get_node_ip 2)
	NODE3_IP=$(get_node_ip 3)

	for id in stonith-node1 stonith-node2 stonith-node3; do
		run_on_node "$NODE1_IP" "sudo pcs stonith delete $id" >/dev/null 2>&1 || true
	done
	run_on_node "$NODE1_IP" "sudo pcs property set stonith-enabled=false" >/dev/null 2>&1 || true

	# Remove the fence agents (unless another package needs them)
	REMOVE_FENCE="for p in fence-agents-all fence-agents-virsh; do if rpm -q \$p >/dev/null 2>&1 && ! rpm -q --whatrequires \$p >/dev/null 2>&1; then sudo dnf -y remove \$p; fi; done"
	for ip in "$NODE1_IP" "$NODE2_IP" "$NODE3_IP"; do
		run_on_node "$ip" "$REMOVE_FENCE" >/dev/null 2>&1 || true
	done
fi

rm -f "$STATE_FILE"
exit 0
