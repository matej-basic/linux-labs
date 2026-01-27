#!/bin/bash
# replication-03 - MySQL Multi-Master Circular Replication Setup
# Configures MySQL in circular multi-master topology (A -> B -> C -> A)

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

if [[ "$NODE_COUNT" -lt 3 ]]; then
    echo "ERROR: This lab requires at least 3 nodes for multi-master topology"
    echo "Current NODE_COUNT: $NODE_COUNT"
    echo "Run: sudo labctl configure set NODE_COUNT 3"
    exit 1
fi

clear
cat << 'EOF'
╔════════════════════════════════════════════════════════════════╗
║    MySQL Multi-Master Replication Lab (replication-03)         ║
╚════════════════════════════════════════════════════════════════╝

OBJECTIVE:
Configure MySQL multi-master replication in circular topology:
1. Node A → Node B (A replicates to B)
2. Node B → Node C (B replicates to C)
3. Node C → Node A (C replicates to A)

This creates a loop: changes made on any node eventually reach all nodes.

TOPOLOGY:
   ┌──────────┐
   │  Node A  │◄─────┐
   │ (Master1)│      │
   └────┬─────┘      │
        │            │
        ▼            │
   ┌──────────┐      │
   │  Node B  │      │
   │ (Master2)├──────┘
   └────┬─────┘
        │
        ▼
   ┌──────────┐
   │  Node C  │
   │ (Master3)│
   └──────────┘

REQUIREMENTS:
✓ Multi-node lab enabled (3+ nodes)
✓ SSH access between all nodes configured
✓ MySQL installed and running on all nodes

TASKS TO COMPLETE:
1. Configure binary logging on all nodes
2. Set unique server-id for each node
3. Create replication users on all nodes
4. Set up replication: A→B, B→C, C→A
5. Test circular replication
6. Demonstrate conflict handling
7. Verify all nodes stay synchronized

VERIFICATION:
The grading script will:
- Verify binary logging on all nodes
- Check replication is active (A→B→C→A)
- Confirm data written to any node reaches all nodes
- Test that the circular topology is working

CHALLENGES:
- Circular replication can cause infinite loops
- Automatic conflict resolution is limited
- Careful about auto_increment handling
- Monitor for replication loops

Begin working on the lab now. Use 'labctl solution replication-03' if you need help.
EOF
