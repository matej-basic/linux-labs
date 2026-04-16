#!/bin/bash
# clustering-02 - Cleanup script

# Load configuration system
if [ -f /opt/linux-labs/lib/load-config.sh ]; then
    source /opt/linux-labs/lib/load-config.sh
    load_lab_config
fi

# Get node IPs
NODE1_IP=$(get_node_ip 1)
NODE2_IP=$(get_node_ip 2)
NODE3_IP=$(get_node_ip 3)

echo "Cleaning up clustering-02 lab environment..."

echo "  [1/3] Removing STONITH resources..."
run_on_node "$NODE1_IP" "sudo pcs stonith delete stonith-node1 &>/dev/null || true" &>/dev/null || true
run_on_node "$NODE1_IP" "sudo pcs stonith delete stonith-node2 &>/dev/null || true" &>/dev/null || true
run_on_node "$NODE1_IP" "sudo pcs stonith delete stonith-node3 &>/dev/null || true" &>/dev/null || true
run_on_node "$NODE1_IP" "sudo pcs property set stonith-enabled=false &>/dev/null || true" &>/dev/null || true

echo "  [2/3] Removing fence agent packages..."
for node_ip in $NODE1_IP $NODE2_IP $NODE3_IP; do
    run_on_node "$node_ip" "sudo dnf -y remove fence-agents-all fence-agents-virsh &>/dev/null || true" &>/dev/null || true
done

echo "  [3/3] Cleaning up configuration files..."
run_on_node "$NODE1_IP" "sudo rm -f /etc/pacemaker/stonith.bak &>/dev/null || true" &>/dev/null || true

echo "Cleanup complete."
