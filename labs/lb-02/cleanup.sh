#!/bin/bash
# lb-02 - Cleanup script

# Load configuration system
if [ -f /opt/linux-labs/lib/load-config.sh ]; then
    source /opt/linux-labs/lib/load-config.sh
    load_lab_config
fi

# Get node IPs
NODE1_IP=$(get_node_ip 1)
NODE2_IP=$(get_node_ip 2)
NODE3_IP=$(get_node_ip 3)

echo "Cleaning up lb-02 lab environment..."

# Stop Nginx on Node 1
run_on_node "$NODE1_IP" "sudo systemctl stop nginx 2>/dev/null || true"
run_on_node "$NODE1_IP" "sudo systemctl disable nginx 2>/dev/null || true"

# Stop Apache on Nodes 2 and 3
run_on_node "$NODE2_IP" "sudo systemctl stop httpd 2>/dev/null || true"
run_on_node "$NODE2_IP" "sudo systemctl disable httpd 2>/dev/null || true"
run_on_node "$NODE3_IP" "sudo systemctl stop httpd 2>/dev/null || true"
run_on_node "$NODE3_IP" "sudo systemctl disable httpd 2>/dev/null || true"

# Remove configuration files
run_on_node "$NODE1_IP" "sudo rm -f /etc/nginx/conf.d/lb.conf 2>/dev/null || true"
run_on_node "$NODE2_IP" "sudo rm -f /var/www/html/health 2>/dev/null || true"
run_on_node "$NODE3_IP" "sudo rm -f /var/www/html/health 2>/dev/null || true"

echo "Cleanup complete."
