#!/bin/bash
# lb-01 - HAProxy Basic Load Balancing Setup
# Sets up HAProxy to load balance across 3 Apache web servers

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
║         HAProxy Basic Load Balancing Lab (lb-01)               ║
╚════════════════════════════════════════════════════════════════╝

OBJECTIVE:
Configure HAProxy to distribute HTTP traffic across 3 Apache web servers:
1. Install and configure HAProxy on Node 1 (load balancer)
2. Configure Apache web servers on Nodes 1, 2, and 3 (backends)
3. Set up round-robin load balancing
4. Enable basic health checks

TOPOLOGY:
          HAProxy (Node 1:80)
               ↓
        ┌──────┼──────┐
        ↓      ↓      ↓
    Node 1  Node 2  Node 3
    :8080   :8080   :8080
   (Apache servers)

REQUIREMENTS:
✓ Multi-node lab enabled (3+ nodes)
✓ SSH access between nodes configured
✓ HAProxy installed on Node 1
✓ Apache (httpd) installed on all 3 nodes

TASKS TO COMPLETE:
1. Install HAProxy on Node 1
2. Install and configure Apache on all 3 nodes to listen on port 8080
3. Create unique index.html on each backend (include node identifier)
4. Configure HAProxy to balance across all 3 backends
5. Set balance algorithm to roundrobin
6. Enable basic HTTP health checks on backends
7. Bind HAProxy to port 80

VERIFICATION:
The grading script will:
- Check HAProxy service is running
- Verify all 3 Apache backends are running on port 8080
- Confirm HAProxy is listening on port 80
- Test load balancing by making multiple requests
- Verify all backends are being used

Begin working on the lab now. Use 'labctl solution lb-01' if you need help.
EOF
