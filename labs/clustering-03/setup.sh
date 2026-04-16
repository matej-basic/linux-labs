#!/bin/bash
# clustering-03 - Advanced Cluster Protection and Split-Brain Prevention
# Configures quorum, ring topology, and advanced failover scenarios

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
║    Advanced Cluster Protection Lab (clustering-03)             ║
╚════════════════════════════════════════════════════════════════╝

OBJECTIVE:
Implement advanced cluster protection mechanisms:
1. Configure quorum voting and cluster composition
2. Set up ring topology for Corosync communication
3. Implement autofencing to prevent split-brain
4. Configure cluster behavior during partitions
5. Test split-brain scenarios and recovery
6. Implement proper failure detection and response

TOPOLOGY:
     ┌──────────────────────────────────┐
     │    3-Node Pacemaker Cluster      │
     │  With Quorum (2 of 3 nodes)      │
     └──────────────────────────────────┘
              ↓
     ┌──────────────────────────────────┐
     │    Ring Topology                 │
     │  (Corosync Primary + Backup)     │
     └──────────────────────────────────┘
              ↓
     ┌──────────────────────────────────┐
     │   STONITH + Autofencing          │
     │  (Prevent concurrent access)     │
     └──────────────────────────────────┘

REQUIREMENTS:
✓ Multi-node lab enabled (3+ nodes)
✓ Cluster from clustering-01 running
✓ STONITH configured (clustering-02)
✓ Pacemaker and Corosync operational
✓ Full SSH access between nodes

TASKS TO COMPLETE:
1. Verify quorum configuration (2 of 3 nodes)
2. Configure ring topology (primary + backup)
3. Set cluster properties for quorum enforcement
4. Configure wait_for_all behavior
5. Set node priority and startup options
6. Configure autofencing parameters
7. Implement cluster recovery strategy
8. Test split-brain scenarios:
   - Isolate 1 node (stays down)
   - Isolate 2 nodes (maintain quorum)
   - Full cluster restart
9. Verify resources stay available during partitions
10. Test full cluster recovery

VERIFICATION:
The grading script will:
- Check quorum configuration (2/3 nodes)
- Verify ring topology configuration
- Confirm autofencing parameters
- Test cluster behavior during partition
- Verify split-brain prevention
- Check cluster recovery after isolation
- Confirm resources remain available

Begin working on the lab now. Use 'labctl solution clustering-03' if you need help.
EOF
