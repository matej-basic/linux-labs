#!/bin/bash
# clustering-03 - Cleanup script

# Load configuration system
if [ -f /opt/linux-labs/lib/load-config.sh ]; then
    source /opt/linux-labs/lib/load-config.sh
    load_lab_config
fi

# Get node IPs
NODE1_IP=$(get_node_ip 1)
NODE2_IP=$(get_node_ip 2)
NODE3_IP=$(get_node_ip 3)

echo "Cleaning up clustering-03 lab environment..."

echo "  [1/2] Resetting cluster properties..."
run_on_node "$NODE1_IP" "sudo pcs property set no-quorum-policy=stop &>/dev/null || true" &>/dev/null || true

echo "  [2/2] Removing autofencing from corosync.conf..."
for node_ip in $NODE1_IP $NODE2_IP $NODE3_IP; do
    run_on_node "$node_ip" "sudo sed -i '/autofencing/d' /etc/corosync/corosync.conf &>/dev/null || true" &>/dev/null || true
done

echo "Cleanup complete."
