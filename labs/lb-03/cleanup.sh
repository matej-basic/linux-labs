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

echo "  [1/4] Stopping services..."
for node_ip in $NODE1_IP $NODE2_IP; do
    run_on_node "$node_ip" "sudo systemctl stop keepalived haproxy httpd 2>/dev/null || true" &>/dev/null
    run_on_node "$node_ip" "sudo systemctl disable keepalived haproxy httpd 2>/dev/null || true" &>/dev/null
done
run_on_node "$NODE3_IP" "sudo systemctl stop httpd 2>/dev/null || true" &>/dev/null
run_on_node "$NODE3_IP" "sudo systemctl disable httpd 2>/dev/null || true" &>/dev/null

echo "  [2/4] Removing packages..."
for node_ip in $NODE1_IP $NODE2_IP; do
    run_on_node "$node_ip" "sudo dnf -y remove keepalived haproxy httpd &>/dev/null || true"
done
run_on_node "$NODE3_IP" "sudo dnf -y remove httpd &>/dev/null || true"

echo "  [3/4] Removing configuration files..."
for node_ip in $NODE1_IP $NODE2_IP; do
    run_on_node "$node_ip" "sudo rm -f /etc/keepalived/keepalived.conf /etc/keepalived/keepalived.conf.rpmsave 2>/dev/null || true"
    run_on_node "$node_ip" "sudo rm -f /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg.rpmsave 2>/dev/null || true"
done
for node_ip in $NODE1_IP $NODE2_IP $NODE3_IP; do
    run_on_node "$node_ip" "sudo rm -f /var/www/html/index.html /etc/httpd/conf/httpd.conf.rpmsave 2>/dev/null || true"
done

echo "  [4/4] Reverting firewall rules..."
for node_ip in $NODE1_IP $NODE2_IP $NODE3_IP; do
    run_on_node "$node_ip" "sudo firewall-cmd --permanent --remove-port=8080/tcp &>/dev/null || true"
    run_on_node "$node_ip" "sudo firewall-cmd --permanent --remove-service=http &>/dev/null || true"
    run_on_node "$node_ip" "sudo firewall-cmd --reload &>/dev/null || true"
done

echo "Cleanup complete."
