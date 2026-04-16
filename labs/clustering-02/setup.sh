#!/bin/bash
# clustering-02 - STONITH Fencing and Failover Testing
# Configures STONITH for reliable failover and cluster protection

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
║       STONITH Fencing and Failover Lab (clustering-02)         ║
╚════════════════════════════════════════════════════════════════╝

OBJECTIVE:
Configure STONITH (Shoot The Other Node In The Head) for failover:
1. Set up STONITH fence devices for all nodes
2. Configure fence agent (ssh-based for testing)
3. Test automatic node fencing
4. Test resource failover when node fails
5. Verify cluster recovery after node restart
6. Monitor failover operations

TOPOLOGY:
   Node 1                Node 2                Node 3
   (Primary)            (Standby)             (Standby)
    Apache               (Monitor)             (Monitor)
      ↓                    ↓                     ↓
   ┌──────────────────────────────────────────────┐
   │      Pacemaker/Corosync HA Cluster          │
   │  (STONITH: SSH fence for node protection)   │
   └──────────────────────────────────────────────┘

REQUIREMENTS:
✓ Multi-node lab enabled (3+ nodes)
✓ SSH access between all nodes (for fence agent)
✓ Cluster from clustering-01 already running
✓ Pacemaker and Corosync on all 3 nodes
✓ Fence agent installed and configured

TASKS TO COMPLETE:
1. Install fence agent (fence_virsh for KVM or fence_ssh)
2. Configure STONITH device for each node
3. Add STONITH resource to Pacemaker
4. Enable STONITH in cluster properties
5. Test fence device functionality
6. Simulate node failure and verify automatic failover
7. Monitor resource migration during failover
8. Verify clean cluster recovery

VERIFICATION:
The grading script will:
- Check STONITH devices are configured
- Verify fence agent is available
- Test fence device operations
- Check STONITH is enabled in cluster
- Verify cluster shows all nodes as online
- Test failover behavior
- Check resource follows node failures

Begin working on the lab now. Use 'labctl solution clustering-02' if you need help.
EOF
