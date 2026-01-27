#!/bin/bash
# replication-01 - Cleanup Script

echo "Cleaning up MySQL replication lab..."

# Load configuration system
if [ -f /opt/linux-labs/lib/load-config.sh ]; then
    source /opt/linux-labs/lib/load-config.sh
fi

if [[ "$NODES_ENABLED" != "true" ]]; then
    echo "Multi-node lab not enabled, skipping cleanup"
    exit 0
fi

if [[ "$NODE_COUNT" -lt 2 ]]; then
    echo "Insufficient nodes, skipping cleanup"
    exit 0
fi

# Get node IPs
MASTER_IP=$(echo "$(get_all_node_ips)" | awk '{print $1}')
SLAVE_IP=$(echo "$(get_all_node_ips)" | awk '{print $2}')

# Stop slave replication
echo "Stopping slave replication..."
run_on_node "$SLAVE_IP" "sudo mysql -u root -plabpassword -e \"STOP SLAVE;\" 2>/dev/null" > /dev/null 2>&1 || true

# Remove replication user from master
echo "Removing replication user..."
run_on_node "$MASTER_IP" "sudo mysql -u root -plabpassword -e \"DROP USER IF EXISTS 'repl'@'%';\" 2>/dev/null" > /dev/null 2>&1 || true

# Reset slave (clear connection info)
echo "Resetting slave configuration..."
run_on_node "$SLAVE_IP" "sudo mysql -u root -plabpassword -e \"RESET SLAVE ALL;\" 2>/dev/null" > /dev/null 2>&1 || true

# Remove any test databases
echo "Removing test databases..."
for node_ip in $MASTER_IP $SLAVE_IP; do
    run_on_node "$node_ip" "sudo mysql -u root -plabpassword -e \"DROP DATABASE IF EXISTS replication_test_%;\" 2>/dev/null" > /dev/null 2>&1 || true
done

echo "✓ MySQL replication lab cleanup complete"
