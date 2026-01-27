#!/bin/bash
# replication-02 - Cleanup Script

echo "Cleaning up PostgreSQL replication lab..."

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
PRIMARY_IP=$(echo "$(get_all_node_ips)" | awk '{print $1}')

# Get all standbys
STANDBY_IPS=$(echo "$(get_all_node_ips)" | awk '{for(i=2;i<=NF;i++) print $i}')

# Stop replication on all standbys
echo "Stopping standbys..."
for standby_ip in $STANDBY_IPS; do
    run_on_node "$standby_ip" "sudo systemctl stop postgresql 2>/dev/null" > /dev/null 2>&1 || true
done

# Remove replication user from primary
echo "Removing replication user..."
run_on_node "$PRIMARY_IP" "cd /tmp && sudo -u postgres psql -c \"DROP ROLE IF EXISTS repl;\" 2>/dev/null" > /dev/null 2>&1 || true

# Remove recovery files from standbys
echo "Removing recovery files..."
for standby_ip in $STANDBY_IPS; do
    run_on_node "$standby_ip" "sudo rm -f /var/lib/pgsql/data/recovery.conf 2>/dev/null" > /dev/null 2>&1 || true
done

# Remove test tables
echo "Removing test data..."
run_on_node "$PRIMARY_IP" "cd /tmp && sudo -u postgres psql -c \"DROP TABLE IF EXISTS repl_test_%;\" 2>/dev/null" > /dev/null 2>&1 || true

echo "✓ PostgreSQL replication lab cleanup complete"
