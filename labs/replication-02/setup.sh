#!/bin/bash
# replication-02 - PostgreSQL Streaming Replication Setup
# Configures PostgreSQL primary-standby replication with continuous WAL streaming

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
║    PostgreSQL Streaming Replication Lab (replication-02)       ║
╚════════════════════════════════════════════════════════════════╝

OBJECTIVE:
Configure PostgreSQL streaming replication where:
1. Primary database server continuously streams WAL records
2. Standby replicas apply these records in real-time
3. Synchronous replication ensures data consistency

TOPOLOGY:
   Primary (Node 1)
       ↓ (WAL streaming)
   Standby (Node 2)
       ↓ (WAL streaming)
   Standby (Node 3, optional)

REQUIREMENTS:
✓ Multi-node lab enabled (2+ nodes)
✓ SSH access between nodes configured
✓ PostgreSQL installed and initialized on all nodes

TASKS TO COMPLETE:
1. Configure WAL archiving on primary
2. Create replication user on primary
3. Configure primary for streaming replication
4. Create standby replicas using pg_basebackup
5. Configure standby for continuous recovery
6. Start replication and verify synchronization
7. Test failover by promoting a standby

VERIFICATION:
The grading script will:
- Check primary is in recovery and archiving WALs
- Verify standbys are connected and streaming
- Confirm data consistency across all nodes
- Test that changes replicate to standbys

Begin working on the lab now. Use 'labctl solution replication-02' if you need help.
EOF
