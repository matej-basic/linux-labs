#!/bin/bash
# lb-01 - Cleanup script

# Load configuration system
if [ -f /opt/linux-labs/lib/load-config.sh ]; then
    source /opt/linux-labs/lib/load-config.sh
    load_lab_config
fi

# Get node IPs
NODE1_IP=$(get_node_ip 1)
NODE2_IP=$(get_node_ip 2)
NODE3_IP=$(get_node_ip 3)

echo "Cleaning up lb-01 lab environment..."

# Stop and disable services on all nodes
for node_ip in $NODE1_IP $NODE2_IP $NODE3_IP; do
    run_on_node "$node_ip" "sudo systemctl stop httpd 2>/dev/null || true"
    run_on_node "$node_ip" "sudo systemctl disable httpd 2>/dev/null || true"
done

# Stop HAProxy on Node 1
run_on_node "$NODE1_IP" "sudo systemctl stop haproxy 2>/dev/null || true"
run_on_node "$NODE1_IP" "sudo systemctl disable haproxy 2>/dev/null || true"

# Remove configuration files
run_on_node "$NODE1_IP" "sudo rm -f /etc/haproxy/haproxy.cfg.bak 2>/dev/null || true"

echo "Cleanup complete."
