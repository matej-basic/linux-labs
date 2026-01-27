#!/bin/bash
# lb-01 - HAProxy Basic Load Balancing Grading Script

# Load configuration system
if [ -f /opt/linux-labs/lib/load-config.sh ]; then
    source /opt/linux-labs/lib/load-config.sh
    load_lab_config
fi

PASS_COUNT=0
FAIL_COUNT=0

# Check multi-node configuration
if [[ "$NODES_ENABLED" != "true" ]]; then
    fail "Multi-node labs not enabled"
    ((FAIL_COUNT++))
    exit 1
fi

if [[ "$NODE_COUNT" -lt 3 ]]; then
    fail "Lab requires at least 3 nodes (current: $NODE_COUNT)"
    ((FAIL_COUNT++))
    exit 1
fi

# Get node IPs
NODE1_IP=$(get_node_ip 1)
NODE2_IP=$(get_node_ip 2)
NODE3_IP=$(get_node_ip 3)

echo "Load Balancer (HAProxy): $NODE1_IP"
echo "Backend Server 1: $NODE1_IP:8080"
echo "Backend Server 2: $NODE2_IP:8080"
echo "Backend Server 3: $NODE3_IP:8080"
echo ""

# Check 1: HAProxy service running
echo -n "1. Checking HAProxy service on Node 1... "
if run_on_node "$NODE1_IP" "sudo systemctl is-active haproxy > /dev/null 2>&1"; then
    pass "HAProxy service running"
    ((PASS_COUNT++))
else
    fail "HAProxy service not running"
    ((FAIL_COUNT++))
fi

# Check 2: Apache running on Node 1
echo -n "2. Checking Apache on Node 1 (port 8080)... "
if run_on_node "$NODE1_IP" "sudo ss -tlnp | grep :8080 | grep -q httpd"; then
    pass "Apache listening on port 8080"
    ((PASS_COUNT++))
else
    fail "Apache not listening on port 8080"
    ((FAIL_COUNT++))
fi

# Check 3: Apache running on Node 2
echo -n "3. Checking Apache on Node 2 (port 8080)... "
if run_on_node "$NODE2_IP" "sudo systemctl is-active httpd > /dev/null 2>&1 && sudo ss -tlnp | grep :8080 | grep -q httpd"; then
    pass "Apache running on Node 2:8080"
    ((PASS_COUNT++))
else
    fail "Apache not running on Node 2:8080"
    ((FAIL_COUNT++))
fi

# Check 4: Apache running on Node 3
echo -n "4. Checking Apache on Node 3 (port 8080)... "
if run_on_node "$NODE3_IP" "sudo systemctl is-active httpd > /dev/null 2>&1 && sudo ss -tlnp | grep :8080 | grep -q httpd"; then
    pass "Apache running on Node 3:8080"
    ((PASS_COUNT++))
else
    fail "Apache not running on Node 3:8080"
    ((FAIL_COUNT++))
fi

# Check 5: HAProxy listening on port 80
echo -n "5. Checking HAProxy listening on port 80... "
if run_on_node "$NODE1_IP" "sudo ss -tlnp | grep :80 | grep -q haproxy"; then
    pass "HAProxy listening on port 80"
    ((PASS_COUNT++))
else
    fail "HAProxy not listening on port 80"
    ((FAIL_COUNT++))
fi

# Check 6: HAProxy configuration includes all backends
echo -n "6. Checking HAProxy backend configuration... "
backend_count=$(run_on_node "$NODE1_IP" "sudo grep -c 'server ' /etc/haproxy/haproxy.cfg 2>/dev/null || echo 0")
if [[ "$backend_count" -ge 3 ]]; then
    pass "HAProxy configured with 3+ backend servers"
    ((PASS_COUNT++))
else
    fail "HAProxy not configured with 3 backend servers (found: $backend_count)"
    ((FAIL_COUNT++))
fi

# Check 7: Test load balancing distribution
echo -n "7. Testing load balancing distribution... "
responses=$(run_on_node "$NODE1_IP" "for i in {1..12}; do curl -s http://localhost 2>/dev/null; done" | sort | uniq | wc -l)
if [[ "$responses" -ge 3 ]]; then
    pass "Load balancing distributes to multiple backends (found $responses unique responses)"
    ((PASS_COUNT++))
else
    fail "Load balancing not distributing properly (only $responses unique responses)"
    ((FAIL_COUNT++))
fi

# Check 8: Verify roundrobin algorithm
echo -n "8. Checking roundrobin algorithm configuration... "
if run_on_node "$NODE1_IP" "sudo grep -q 'balance roundrobin' /etc/haproxy/haproxy.cfg 2>/dev/null"; then
    pass "Roundrobin algorithm configured"
    ((PASS_COUNT++))
else
    fail "Roundrobin algorithm not configured"
    ((FAIL_COUNT++))
fi

echo ""
echo "════════════════════════════════════════════════"
echo "Results: $PASS_COUNT passed, $FAIL_COUNT failed"
echo "════════════════════════════════════════════════"

if [[ $FAIL_COUNT -eq 0 ]]; then
    pass "Lab completed successfully"
    exit 0
else
    fail "Lab incomplete"
    exit 1
fi
