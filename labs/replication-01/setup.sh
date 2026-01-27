#!/bin/bash
# replication-01 - MySQL Master-Slave Replication Setup
# Sets up MySQL replication on multiple nodes

set -e

# Load configuration system
if [ -f /opt/linux-labs/lib/load-config.sh ]; then
    source /opt/linux-labs/lib/load-config.sh
    load_lab_config
fi

# Verify multi-node configuration
if [[ "$NODES_ENABLED" != "true" ]]; then
    echo "ERROR: This lab requires multi-node setup enabled"
    echo "Run: sudo labctl configure interactive"
    echo "Then answer 'y' for multi-node labs"
    exit 1
fi

if [[ "$NODE_COUNT" -lt 2 ]]; then
    echo "ERROR: This lab requires at least 2 nodes"
    echo "Current NODE_COUNT: $NODE_COUNT"
    echo "Run: sudo labctl configure set NODE_COUNT 2"
    exit 1
fi

clear
cat << 'EOF'
╔════════════════════════════════════════════════════════════════╗
║         MySQL Master-Slave Replication Lab (replication-01)    ║
╚════════════════════════════════════════════════════════════════╝

OBJECTIVE:
Configure MySQL master-slave replication where:
1. Master node accepts writes and generates binary logs
2. Slave node replicates changes from master
3. Data automatically syncs from master to slave

TOPOLOGY:
   Master (Node 1)
       ↓ (binary logs)
   Slave (Node 2)

REQUIREMENTS:
✓ Multi-node lab enabled (2+ nodes)
✓ SSH access between nodes configured
✓ MySQL installed and running on both nodes

TASKS TO COMPLETE:
1. Configure master with binary logging enabled
2. Create replication user on master
3. Get binary log position from master
4. Configure slave to connect to master
5. Start replication on slave
6. Verify data replication works

VERIFICATION:
The grading script will:
- Check master has binary logging enabled
- Verify slave is connected to master
- Test that writes on master appear on slave
- Confirm replication is synchronized

Begin working on the lab now. Use 'labctl solution replication-01' if you need help.
EOF
