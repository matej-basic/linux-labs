#!/bin/bash
# lb-02 - Nginx Reverse Proxy Grading Script

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

echo "Nginx Reverse Proxy: $NODE1_IP"
echo "Backend Server 1: $NODE2_IP:8080"
echo "Backend Server 2: $NODE3_IP:8080"
echo ""

# Check 1: Nginx service running
echo -n "1. Checking Nginx service on Node 1... "
if run_on_node "$NODE1_IP" "sudo systemctl is-active nginx > /dev/null 2>&1"; then
    pass "Nginx service running"
    ((PASS_COUNT++))
else
    fail "Nginx service not running"
    ((FAIL_COUNT++))
fi

# Check 2: Nginx listening on port 80
echo -n "2. Checking Nginx listening on port 80... "
if run_on_node "$NODE1_IP" "sudo ss -tlnp | grep :80 | grep -q nginx"; then
    pass "Nginx listening on port 80"
    ((PASS_COUNT++))
else
    fail "Nginx not listening on port 80"
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

# Check 5: Health check endpoint exists on Node 2
echo -n "5. Checking health endpoint on Node 2... "
health_check=$(run_on_node "$NODE2_IP" "curl -s http://localhost:8080/health 2>/dev/null" | head -1)
if [[ -n "$health_check" ]]; then
    pass "Health endpoint accessible on Node 2"
    ((PASS_COUNT++))
else
    fail "Health endpoint not accessible on Node 2"
    ((FAIL_COUNT++))
fi

# Check 6: Health check endpoint exists on Node 3
echo -n "6. Checking health endpoint on Node 3... "
health_check=$(run_on_node "$NODE3_IP" "curl -s http://localhost:8080/health 2>/dev/null" | head -1)
if [[ -n "$health_check" ]]; then
    pass "Health endpoint accessible on Node 3"
    ((PASS_COUNT++))
else
    fail "Health endpoint not accessible on Node 3"
    ((FAIL_COUNT++))
fi

# Check 7: Nginx upstream configuration exists
echo -n "7. Checking Nginx upstream configuration... "
if run_on_node "$NODE1_IP" "sudo grep -q 'upstream' /etc/nginx/nginx.conf 2>/dev/null || sudo grep -q 'upstream' /etc/nginx/conf.d/*.conf 2>/dev/null"; then
    pass "Nginx upstream configuration found"
    ((PASS_COUNT++))
else
    fail "Nginx upstream configuration not found"
    ((FAIL_COUNT++))
fi

# Check 8: Proxy pass configured
echo -n "8. Checking proxy_pass directive... "
if run_on_node "$NODE1_IP" "sudo grep -q 'proxy_pass' /etc/nginx/nginx.conf 2>/dev/null || sudo grep -q 'proxy_pass' /etc/nginx/conf.d/*.conf 2>/dev/null"; then
    pass "proxy_pass directive configured"
    ((PASS_COUNT++))
else
    fail "proxy_pass directive not configured"
    ((FAIL_COUNT++))
fi

# Check 9: Health check parameters configured
echo -n "9. Checking health check parameters... "
if run_on_node "$NODE1_IP" "sudo grep -E 'max_fails|fail_timeout' /etc/nginx/nginx.conf /etc/nginx/conf.d/*.conf 2>/dev/null | grep -q ."; then
    pass "Health check parameters configured"
    ((PASS_COUNT++))
else
    fail "Health check parameters not configured"
    ((FAIL_COUNT++))
fi

# Check 10: Proxy headers configured
echo -n "10. Checking proxy headers... "
if run_on_node "$NODE1_IP" "sudo grep -q 'proxy_set_header' /etc/nginx/nginx.conf 2>/dev/null || sudo grep -q 'proxy_set_header' /etc/nginx/conf.d/*.conf 2>/dev/null"; then
    pass "Proxy headers configured"
    ((PASS_COUNT++))
else
    fail "Proxy headers not configured"
    ((FAIL_COUNT++))
fi

# Check 11: Test reverse proxy functionality
echo -n "11. Testing reverse proxy... "
response=$(run_on_node "$NODE1_IP" "curl -s http://127.0.0.1 2>/dev/null" | head -1)
if [[ -n "$response" ]]; then
    pass "Reverse proxy returning content"
    ((PASS_COUNT++))
else
    fail "Reverse proxy not returning content"
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
