#!/bin/bash
# lb-03 - Cleanup script

# Load configuration system
if [ -f /opt/linux-labs/lib/load-config.sh ]; then
    source /opt/linux-labs/lib/load-config.sh
    load_lab_config
fi

# Get node IPs
NODE1_IP=$(get_node_ip 1)
NODE2_IP=$(get_node_ip 2)
NODE3_IP=$(get_node_ip 3)

echo "Cleaning up lb-03 lab environment..."

# Stop services on Nodes 1 and 2
for node_ip in $NODE1_IP $NODE2_IP; do
    run_on_node "$node_ip" "sudo systemctl stop keepalived 2>/dev/null || true"
    run_on_node "$node_ip" "sudo systemctl disable keepalived 2>/dev/null || true"
    run_on_node "$node_ip" "sudo systemctl stop haproxy 2>/dev/null || true"
    run_on_node "$node_ip" "sudo systemctl disable haproxy 2>/dev/null || true"
    run_on_node "$node_ip" "sudo systemctl stop httpd 2>/dev/null || true"
    run_on_node "$node_ip" "sudo systemctl disable httpd 2>/dev/null || true"
done

# Stop Apache on Node 3
run_on_node "$NODE3_IP" "sudo systemctl stop httpd 2>/dev/null || true"
run_on_node "$NODE3_IP" "sudo systemctl disable httpd 2>/dev/null || true"

# Remove configuration files
run_on_node "$NODE1_IP" "sudo rm -f /etc/keepalived/keepalived.conf.bak 2>/dev/null || true"
run_on_node "$NODE2_IP" "sudo rm -f /etc/keepalived/keepalived.conf.bak 2>/dev/null || true"
run_on_node "$NODE1_IP" "sudo rm -f /etc/haproxy/haproxy.cfg.bak 2>/dev/null || true"
run_on_node "$NODE2_IP" "sudo rm -f /etc/haproxy/haproxy.cfg.bak 2>/dev/null || true"

echo "Cleanup complete."
