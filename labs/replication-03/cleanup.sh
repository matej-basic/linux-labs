#!/bin/bash
# replication-03 - Cleanup Script

echo "Cleaning up MySQL multi-master replication lab..."

# Load configuration system
if [ -f /opt/linux-labs/lib/load-config.sh ]; then
    source /opt/linux-labs/lib/load-config.sh
fi

if [[ "$NODES_ENABLED" != "true" ]]; then
    echo "Multi-node lab not enabled, skipping cleanup"
    exit 0
fi

if [[ "$NODE_COUNT" -lt 3 ]]; then
    echo "Insufficient nodes, skipping cleanup"
    exit 0
fi

# Get node IPs
NODE_A=$(echo "$(get_all_node_ips)" | awk '{print $1}')
NODE_B=$(echo "$(get_all_node_ips)" | awk '{print $2}')
NODE_C=$(echo "$(get_all_node_ips)" | awk '{print $3}')

# Stop all slaves
echo "Stopping replication on all nodes..."
for node_ip in $NODE_A $NODE_B $NODE_C; do
    run_on_node "$node_ip" "sudo mysql -u root -plabpassword -e \"STOP SLAVE;\" 2>/dev/null" > /dev/null 2>&1 || true
done

# Reset slave info on all nodes
echo "Resetting slave configuration..."
for node_ip in $NODE_A $NODE_B $NODE_C; do
    run_on_node "$node_ip" "sudo mysql -u root -plabpassword -e \"RESET SLAVE ALL;\" 2>/dev/null" > /dev/null 2>&1 || true
done

# Remove replication users from all nodes
echo "Removing replication users..."
for node_ip in $NODE_A $NODE_B $NODE_C; do
    run_on_node "$node_ip" "sudo mysql -u root -plabpassword -e \"DROP USER IF EXISTS 'repl'@'%';\" 2>/dev/null" > /dev/null 2>&1 || true
done

# Remove test databases
echo "Removing test databases..."
for node_ip in $NODE_A $NODE_B $NODE_C; do
    run_on_node "$node_ip" "sudo mysql -u root -plabpassword -e \"DROP DATABASE IF EXISTS mm_test_%;\" 2>/dev/null" > /dev/null 2>&1 || true
done

echo "✓ MySQL multi-master replication lab cleanup complete"
