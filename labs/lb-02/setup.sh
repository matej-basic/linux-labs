#!/bin/bash
# lb-02 - Nginx Reverse Proxy with Health Checks
# Sets up Nginx as a reverse proxy with advanced health monitoring

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
║     Nginx Reverse Proxy with Health Checks Lab (lb-02)         ║
╚════════════════════════════════════════════════════════════════╝

OBJECTIVE:
Configure Nginx as a reverse proxy with advanced health monitoring:
1. Install and configure Nginx on Node 1 (reverse proxy)
2. Configure Apache web servers on Nodes 2 and 3 (backends)
3. Implement health checks with automatic backend failover
4. Configure proper proxy headers
5. Enable connection keepalive to backends

TOPOLOGY:
        Nginx Reverse Proxy (Node 1:80)
                    ↓
            ┌───────┴────────┐
            ↓                ↓
        Node 2:8080      Node 3:8080
       (Apache)         (Apache)

REQUIREMENTS:
✓ Multi-node lab enabled (3+ nodes)
✓ SSH access between nodes configured
✓ Nginx installed on Node 1
✓ Apache (httpd) installed on Nodes 2 and 3

TASKS TO COMPLETE:
1. Install Nginx on Node 1
2. Install and configure Apache on Nodes 2 and 3 (port 8080)
3. Create health check endpoint (/health) on each backend
4. Configure Nginx upstream with health checks
5. Set up proper proxy headers (X-Forwarded-For, Host, etc.)
6. Enable passive health checks (max_fails, fail_timeout)
7. Configure keepalive connections to backends
8. Test automatic failover when a backend goes down

VERIFICATION:
The grading script will:
- Check Nginx service is running
- Verify Apache backends are running on Nodes 2 and 3
- Confirm health check endpoints are accessible
- Test upstream configuration and proxy headers
- Verify health check parameters are configured
- Test failover behavior

Begin working on the lab now. Use 'labctl solution lb-02' if you need help.
EOF
