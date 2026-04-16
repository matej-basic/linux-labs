#!/bin/bash
# clustering-01 - Basic HA Cluster Setup with Pacemaker/Corosync
# Sets up a basic 3-node cluster for high availability

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
    echo "ERROR: This lab requires at least 3 nodes"
    echo "Current NODE_COUNT: $NODE_COUNT"
    echo "Run: sudo labctl configure set NODE_COUNT 3"
    exit 1
fi

clear
cat << 'EOF'
╔════════════════════════════════════════════════════════════════╗
║         Basic HA Cluster Setup Lab (clustering-01)             ║
╚════════════════════════════════════════════════════════════════╝

OBJECTIVE:
Set up a basic 3-node Pacemaker/Corosync HA cluster:
1. Install Pacemaker and Corosync on all 3 nodes
2. Configure cluster communication between nodes
3. Initialize the cluster with basic quorum (2 nodes)
4. Add a simple resource (Apache web server)
5. Configure resource constraints
6. Test cluster communication and status

TOPOLOGY:
   ┌─────────────┬─────────────┬─────────────┐
   │   Node 1    │   Node 2    │   Node 3    │
   │ Pacemaker   │ Pacemaker   │ Pacemaker   │
   │ Corosync    │ Corosync    │ Corosync    │
   │ (Apache)    │             │             │
   └─────────────┴─────────────┴─────────────┘
         ↓             ↓             ↓
    Cluster Communication (Corosync rings)

REQUIREMENTS:
✓ Multi-node lab enabled (3+ nodes)
✓ SSH access between nodes configured
✓ Pacemaker installed on all 3 nodes
✓ Corosync installed on all 3 nodes
✓ Cluster communication enabled

TASKS TO COMPLETE:
1. Install Pacemaker and Corosync on all 3 nodes
2. Configure Corosync cluster communication
3. Set cluster authentication key
4. Synchronize configuration across nodes
5. Enable and start cluster services
6. Verify cluster is healthy and all nodes are present
7. Configure a managed resource (Apache)
8. Verify resource is running on one of the nodes

VERIFICATION:
The grading script will:
- Check Pacemaker and Corosync running on all nodes
- Verify cluster has 3 members
- Check cluster quorum is set
- Verify Apache resource is running
- Test cluster command execution
- Verify cluster status shows all nodes online

Begin working on the lab now. Use 'labctl solution clustering-01' if you need help.
EOF
