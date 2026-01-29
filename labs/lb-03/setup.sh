#!/bin/bash
# lb-03 - Advanced Load Balancing with Keepalived VIP
# Sets up HA load balancing with automatic failover

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
║   Advanced Load Balancing with Keepalived VIP Lab (lb-03)      ║
╚════════════════════════════════════════════════════════════════╝

OBJECTIVE:
Implement high availability load balancing using keepalived VIP:
1. Set up HAProxy on Nodes 1 and 2 (active/passive)
2. Configure keepalived to manage a Virtual IP (VIP)
3. Set up Apache backends on all 3 nodes
4. Implement automatic failover when master goes down
5. Configure priority-based VRRP election

TOPOLOGY:
          VIP: 172.25.250.100 (floats between Node 1/2)
                      ↓
         ┌────────────┴────────────┐
         ↓                         ↓
    HAProxy (Node 1)          HAProxy (Node 2)
     MASTER (priority 100)    BACKUP (priority 90)
         ↓                         ↓
         └─────────┬───────────────┘
                   ↓
          ┌────────┼────────┐
          ↓        ↓        ↓
       Node 1   Node 2   Node 3
       :8080    :8080    :8080
      (Apache backends)

REQUIREMENTS:
✓ Multi-node lab enabled (3+ nodes)
✓ SSH access between nodes configured
✓ HAProxy installed on Nodes 1 and 2
✓ Keepalived installed on Nodes 1 and 2
✓ Apache (httpd) installed on all 3 nodes

TASKS TO COMPLETE:
1. Install HAProxy and keepalived on Nodes 1 and 2
2. Install Apache on all 3 nodes (port 8080)
3. Configure identical HAProxy configs on Nodes 1 and 2
4. Configure keepalived with VIP on Nodes 1 and 2
5. Set Node 1 as MASTER (priority 100)
6. Set Node 2 as BACKUP (priority 90)
7. Configure VRRP authentication
8. Enable non-preemptive mode for stability
9. Test VIP failover when master fails
10. Verify automatic VIP migration

VERIFICATION:
The grading script will:
- Check HAProxy running on Nodes 1 and 2
- Verify keepalived running on Nodes 1 and 2
- Confirm VIP is configured and active
- Test Apache backends on all 3 nodes
- Verify VRRP priority configuration
- Test automatic failover functionality
- Check VIP responds to requests

Begin working on the lab now. Use 'labctl solution lb-03' if you need help.
EOF
