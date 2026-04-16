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

echo "  [1/4] Stopping services..."
run_on_node "$NODE1_IP" "sudo systemctl stop nginx 2>/dev/null || true" &>/dev/null
run_on_node "$NODE1_IP" "sudo systemctl disable nginx 2>/dev/null || true" &>/dev/null
for node_ip in $NODE2_IP $NODE3_IP; do
    run_on_node "$node_ip" "sudo systemctl stop httpd 2>/dev/null || true" &>/dev/null
    run_on_node "$node_ip" "sudo systemctl disable httpd 2>/dev/null || true" &>/dev/null
done

echo "  [2/4] Removing packages..."
run_on_node "$NODE1_IP" "sudo dnf -y remove nginx &>/dev/null || true"
for node_ip in $NODE2_IP $NODE3_IP; do
    run_on_node "$node_ip" "sudo dnf -y remove httpd &>/dev/null || true"
done

echo "  [3/4] Removing configuration files..."
run_on_node "$NODE1_IP" "sudo rm -f /etc/nginx/conf.d/lb.conf /etc/nginx/conf.d/lb.conf.rpmsave 2>/dev/null || true"
for node_ip in $NODE2_IP $NODE3_IP; do
    run_on_node "$node_ip" "sudo rm -f /var/www/html/index.html /var/www/html/health /etc/httpd/conf/httpd.conf.rpmsave 2>/dev/null || true"
done

echo "  [4/4] Reverting firewall rules..."
for node_ip in $NODE1_IP $NODE2_IP $NODE3_IP; do
    run_on_node "$node_ip" "sudo firewall-cmd --permanent --remove-port=8080/tcp &>/dev/null || true"
    run_on_node "$node_ip" "sudo firewall-cmd --permanent --remove-service=http &>/dev/null || true"
    run_on_node "$node_ip" "sudo firewall-cmd --reload &>/dev/null || true"
done

echo "Cleanup complete."
