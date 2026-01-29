#!/bin/bash
# lb-03 - Advanced Load Balancing with Keepalived Grading Script

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

# VIP should be configured in the keepalived.conf
VIP="172.25.250.100"

echo "HAProxy Master: $NODE1_IP"
echo "HAProxy Backup: $NODE2_IP"
echo "Virtual IP: $VIP"
echo "Backend Servers: $NODE1_IP:8080, $NODE2_IP:8080, $NODE3_IP:8080"
echo ""

# Check 1: HAProxy running on Node 1
echo -n "1. Checking HAProxy on Node 1... "
if run_on_node "$NODE1_IP" "sudo systemctl is-active haproxy > /dev/null 2>&1"; then
    pass "HAProxy running on Node 1"
    ((PASS_COUNT++))
else
    fail "HAProxy not running on Node 1"
    ((FAIL_COUNT++))
fi

# Check 2: HAProxy running on Node 2
echo -n "2. Checking HAProxy on Node 2... "
if run_on_node "$NODE2_IP" "sudo systemctl is-active haproxy > /dev/null 2>&1"; then
    pass "HAProxy running on Node 2"
    ((PASS_COUNT++))
else
    fail "HAProxy not running on Node 2"
    ((FAIL_COUNT++))
fi

# Check 3: Keepalived running on Node 1
echo -n "3. Checking keepalived on Node 1... "
if run_on_node "$NODE1_IP" "sudo systemctl is-active keepalived > /dev/null 2>&1"; then
    pass "Keepalived running on Node 1"
    ((PASS_COUNT++))
else
    fail "Keepalived not running on Node 1"
    ((FAIL_COUNT++))
fi

# Check 4: Keepalived running on Node 2
echo -n "4. Checking keepalived on Node 2... "
if run_on_node "$NODE2_IP" "sudo systemctl is-active keepalived > /dev/null 2>&1"; then
    pass "Keepalived running on Node 2"
    ((PASS_COUNT++))
else
    fail "Keepalived not running on Node 2"
    ((FAIL_COUNT++))
fi

# Check 5: VIP configured in keepalived
echo -n "5. Checking VIP configuration... "
vip_config=$(run_on_node "$NODE1_IP" "sudo grep -r '172.25.250.100' /etc/keepalived/ 2>/dev/null || echo ''")
if [[ -n "$vip_config" ]]; then
    pass "VIP configured in keepalived"
    ((PASS_COUNT++))
else
    fail "VIP not configured in keepalived"
    ((FAIL_COUNT++))
fi

# Check 6: VIP is active on one of the nodes
echo -n "6. Checking VIP is active... "
vip_node1=$(run_on_node "$NODE1_IP" "ip addr show | grep -c '172.25.250.100' 2>/dev/null || echo 0")
vip_node2=$(run_on_node "$NODE2_IP" "ip addr show | grep -c '172.25.250.100' 2>/dev/null || echo 0")
if [[ "$vip_node1" -gt 0 ]] || [[ "$vip_node2" -gt 0 ]]; then
    if [[ "$vip_node1" -gt 0 ]]; then
        pass "VIP active on Node 1 (MASTER)"
    else
        pass "VIP active on Node 2 (BACKUP)"
    fi
    ((PASS_COUNT++))
else
    fail "VIP not active on any node"
    ((FAIL_COUNT++))
fi

# Check 7: VRRP priority configured
echo -n "7. Checking VRRP priority settings... "
node1_priority=$(run_on_node "$NODE1_IP" "sudo grep 'priority' /etc/keepalived/keepalived.conf 2>/dev/null | head -1 | grep -oE '[0-9]+' || echo 0")
node2_priority=$(run_on_node "$NODE2_IP" "sudo grep 'priority' /etc/keepalived/keepalived.conf 2>/dev/null | head -1 | grep -oE '[0-9]+' || echo 0")
if [[ "$node1_priority" -gt "$node2_priority" ]] && [[ "$node1_priority" -ge 100 ]]; then
    pass "Priority configured correctly (Node 1: $node1_priority, Node 2: $node2_priority)"
    ((PASS_COUNT++))
else
    fail "Priority not configured correctly (Node 1: $node1_priority, Node 2: $node2_priority)"
    ((FAIL_COUNT++))
fi

# Check 8: Apache running on Node 1
echo -n "8. Checking Apache on Node 1 (port 8080)... "
if run_on_node "$NODE1_IP" "sudo ss -tlnp | grep :8080 | grep -q httpd"; then
    pass "Apache running on Node 1:8080"
    ((PASS_COUNT++))
else
    fail "Apache not running on Node 1:8080"
    ((FAIL_COUNT++))
fi

# Check 9: Apache running on Node 2
echo -n "9. Checking Apache on Node 2 (port 8080)... "
if run_on_node "$NODE2_IP" "sudo ss -tlnp | grep :8080 | grep -q httpd"; then
    pass "Apache running on Node 2:8080"
    ((PASS_COUNT++))
else
    fail "Apache not running on Node 2:8080"
    ((FAIL_COUNT++))
fi

# Check 10: Apache running on Node 3
echo -n "10. Checking Apache on Node 3 (port 8080)... "
if run_on_node "$NODE3_IP" "sudo systemctl is-active httpd > /dev/null 2>&1 && sudo ss -tlnp | grep :8080 | grep -q httpd"; then
    pass "Apache running on Node 3:8080"
    ((PASS_COUNT++))
else
    fail "Apache not running on Node 3:8080"
    ((FAIL_COUNT++))
fi

# Check 11: HAProxy backend configuration
echo -n "11. Checking HAProxy backend configuration... "
backend_count=$(run_on_node "$NODE1_IP" "sudo grep -c 'server ' /etc/haproxy/haproxy.cfg 2>/dev/null || echo 0")
if [[ "$backend_count" -ge 3 ]]; then
    pass "HAProxy configured with 3+ backend servers"
    ((PASS_COUNT++))
else
    fail "HAProxy not configured with 3 backend servers (found: $backend_count)"
    ((FAIL_COUNT++))
fi

# Check 12: VIP responds to HTTP requests
echo -n "12. Testing VIP HTTP access... "
vip_response=$(run_on_node "$NODE1_IP" "curl -s --connect-timeout 5 http://$VIP 2>/dev/null | head -1")
if [[ -n "$vip_response" ]]; then
    pass "VIP responds to HTTP requests"
    ((PASS_COUNT++))
else
    fail "VIP does not respond to HTTP requests"
    ((FAIL_COUNT++))
fi

# Check 13: VRRP authentication configured
echo -n "13. Checking VRRP authentication... "
if run_on_node "$NODE1_IP" "sudo grep -q 'auth_type' /etc/keepalived/keepalived.conf 2>/dev/null"; then
    pass "VRRP authentication configured"
    ((PASS_COUNT++))
else
    fail "VRRP authentication not configured"
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
