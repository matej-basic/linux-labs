#!/bin/bash
# clustering-01 - Cleanup script

# Load configuration system
if [ -f /opt/linux-labs/lib/load-config.sh ]; then
    source /opt/linux-labs/lib/load-config.sh
    load_lab_config
fi

# Get node IPs
NODE1_IP=$(get_node_ip 1)
NODE2_IP=$(get_node_ip 2)
NODE3_IP=$(get_node_ip 3)

echo "Cleaning up clustering-01 lab environment..."

echo "  [1/3] Stopping services..."
for node_ip in $NODE1_IP $NODE2_IP $NODE3_IP; do
    run_on_node "$node_ip" "sudo systemctl stop pacemaker corosync 2>/dev/null || true" &>/dev/null
    run_on_node "$node_ip" "sudo systemctl disable pacemaker corosync 2>/dev/null || true" &>/dev/null
done

echo "  [2/3] Removing packages..."
for node_ip in $NODE1_IP $NODE2_IP $NODE3_IP; do
    run_on_node "$node_ip" "sudo dnf -y remove pacemaker corosync pcs &>/dev/null || true"
done

echo "  [3/3] Removing configuration files..."
for node_ip in $NODE1_IP $NODE2_IP $NODE3_IP; do
    run_on_node "$node_ip" "sudo rm -f /etc/corosync/corosync.conf /etc/corosync/corosync.conf.bak /etc/corosync/authkey /etc/corosync/authkey.bak 2>/dev/null || true"
done

echo "Cleanup complete."
