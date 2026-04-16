#!/bin/bash
# clustering-01 - Basic HA Cluster Setup Grading Script

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

echo "Cluster Node 1: $NODE1_IP"
echo "Cluster Node 2: $NODE2_IP"
echo "Cluster Node 3: $NODE3_IP"
echo ""

# Check 1: Corosync running on Node 1
echo -n "1. Checking Corosync on Node 1... "
if run_on_node "$NODE1_IP" "sudo systemctl is-active corosync > /dev/null 2>&1"; then
    pass "Corosync running on Node 1"
    ((PASS_COUNT++))
else
    fail "Corosync not running on Node 1"
    ((FAIL_COUNT++))
fi

# Check 2: Corosync running on Node 2
echo -n "2. Checking Corosync on Node 2... "
if run_on_node "$NODE2_IP" "sudo systemctl is-active corosync > /dev/null 2>&1"; then
    pass "Corosync running on Node 2"
    ((PASS_COUNT++))
else
    fail "Corosync not running on Node 2"
    ((FAIL_COUNT++))
fi

# Check 3: Corosync running on Node 3
echo -n "3. Checking Corosync on Node 3... "
if run_on_node "$NODE3_IP" "sudo systemctl is-active corosync > /dev/null 2>&1"; then
    pass "Corosync running on Node 3"
    ((PASS_COUNT++))
else
    fail "Corosync not running on Node 3"
    ((FAIL_COUNT++))
fi

# Check 4: Pacemaker running on Node 1
echo -n "4. Checking Pacemaker on Node 1... "
if run_on_node "$NODE1_IP" "sudo systemctl is-active pacemaker > /dev/null 2>&1"; then
    pass "Pacemaker running on Node 1"
    ((PASS_COUNT++))
else
    fail "Pacemaker not running on Node 1"
    ((FAIL_COUNT++))
fi

# Check 5: Pacemaker running on Node 2
echo -n "5. Checking Pacemaker on Node 2... "
if run_on_node "$NODE2_IP" "sudo systemctl is-active pacemaker > /dev/null 2>&1"; then
    pass "Pacemaker running on Node 2"
    ((PASS_COUNT++))
else
    fail "Pacemaker not running on Node 2"
    ((FAIL_COUNT++))
fi

# Check 6: Pacemaker running on Node 3
echo -n "6. Checking Pacemaker on Node 3... "
if run_on_node "$NODE3_IP" "sudo systemctl is-active pacemaker > /dev/null 2>&1"; then
    pass "Pacemaker running on Node 3"
    ((PASS_COUNT++))
else
    fail "Pacemaker not running on Node 3"
    ((FAIL_COUNT++))
fi

# Check 7: Cluster has 3 nodes
echo -n "7. Checking cluster membership... "
cluster_nodes=$(run_on_node "$NODE1_IP" "sudo crm_mon -1 2>/dev/null | grep -c 'Online:' || echo 0")
if [[ "$cluster_nodes" -ge 1 ]]; then
    pass "Cluster is responding"
    ((PASS_COUNT++))
else
    fail "Cluster not responding"
    ((FAIL_COUNT++))
fi

# Check 8: Cluster status shows 3 nodes
echo -n "8. Checking all 3 nodes are online... "
node_count=$(run_on_node "$NODE1_IP" "sudo crm_node -l 2>/dev/null | grep -c 'member' || echo 0")
if [[ "$node_count" -ge 3 ]]; then
    pass "All 3 nodes are online in cluster"
    ((PASS_COUNT++))
else
    fail "Not all 3 nodes online (found: $node_count)"
    ((FAIL_COUNT++))
fi

# Check 9: Apache installed and configured on Node 1
echo -n "9. Checking Apache on Node 1... "
if run_on_node "$NODE1_IP" "sudo systemctl list-unit-files | grep -q httpd"; then
    pass "Apache installed on Node 1"
    ((PASS_COUNT++))
else
    fail "Apache not installed on Node 1"
    ((FAIL_COUNT++))
fi

# Check 10: Pacemaker resource configured
echo -n "10. Checking Pacemaker resource configuration... "
resource_check=$(run_on_node "$NODE1_IP" "sudo pcs resource status 2>/dev/null | grep -i apache || echo ''" || echo "")
if [[ -n "$resource_check" ]]; then
    pass "Apache resource configured in Pacemaker"
    ((PASS_COUNT++))
else
    fail "Apache resource not found in Pacemaker"
    ((FAIL_COUNT++))
fi

# Check 11: Quorum configured
echo -n "11. Checking cluster quorum... "
quorum_check=$(run_on_node "$NODE1_IP" "sudo crm_mon -1 2>/dev/null | grep -i quorum || echo ''" || echo "")
if [[ -n "$quorum_check" ]]; then
    pass "Cluster quorum is configured"
    ((PASS_COUNT++))
else
    fail "Cluster quorum not configured"
    ((FAIL_COUNT++))
fi

# Check 12: No split-brain (all nodes agree on status)
echo -n "12. Checking cluster consistency... "
node_members=$(run_on_node "$NODE1_IP" "sudo crm_node -l 2>/dev/null | grep -c 'member' || echo 0")
if [[ "$node_members" -ge 3 ]]; then
    pass "Cluster nodes are communicating"
    ((PASS_COUNT++))
else
    fail "Cluster communication issue"
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
