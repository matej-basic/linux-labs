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
echo "  [1/4] Stopping services..."
for node_ip in $NODE1_IP $NODE2_IP $NODE3_IP; do
    run_on_node "$node_ip" "sudo systemctl stop httpd 2>/dev/null || true" &>/dev/null
    run_on_node "$node_ip" "sudo systemctl disable httpd 2>/dev/null || true" &>/dev/null
done
run_on_node "$NODE1_IP" "sudo systemctl stop haproxy 2>/dev/null || true" &>/dev/null
run_on_node "$NODE1_IP" "sudo systemctl disable haproxy 2>/dev/null || true" &>/dev/null

# Remove packages
echo "  [2/4] Removing packages..."
run_on_node "$NODE1_IP" "sudo dnf -y remove haproxy httpd &>/dev/null || true"
for node_ip in $NODE2_IP $NODE3_IP; do
    run_on_node "$node_ip" "sudo dnf -y remove httpd &>/dev/null || true"
done

# Remove leftover files and configs
echo "  [3/4] Removing configuration files..."
run_on_node "$NODE1_IP" "sudo rm -f /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg.rpmsave 2>/dev/null || true"
for node_ip in $NODE1_IP $NODE2_IP $NODE3_IP; do
    run_on_node "$node_ip" "sudo rm -f /var/www/html/index.html /etc/httpd/conf/httpd.conf.rpmsave 2>/dev/null || true"
done

# Revert firewall rules
echo "  [4/4] Reverting firewall rules..."
for node_ip in $NODE1_IP $NODE2_IP $NODE3_IP; do
    run_on_node "$node_ip" "sudo firewall-cmd --permanent --remove-port=8080/tcp &>/dev/null || true"
    run_on_node "$node_ip" "sudo firewall-cmd --permanent --remove-service=http &>/dev/null || true"
    run_on_node "$node_ip" "sudo firewall-cmd --reload &>/dev/null || true"
done

echo "Cleanup complete."
