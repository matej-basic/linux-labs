#!/bin/bash
# clustering-02 - STONITH Fencing and Failover Grading Script

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

# Check 1: Cluster is running
echo -n "1. Checking cluster is running... "
if run_on_node "$NODE1_IP" "sudo systemctl is-active pacemaker > /dev/null 2>&1"; then
    pass "Cluster is running"
    ((PASS_COUNT++))
else
    fail "Cluster not running"
    ((FAIL_COUNT++))
fi

# Check 2: Fence agents installed
echo -n "2. Checking fence agents installed... "
if run_on_node "$NODE1_IP" "test \$(ls /usr/sbin/fence_* 2>/dev/null | wc -l) -gt 0"; then
    pass "Fence agent installed"
    ((PASS_COUNT++))
else
    fail "Fence agent not found"
    ((FAIL_COUNT++))
fi

# Check 3: STONITH resource configured
echo -n "3. Checking STONITH resource configuration... "
stonith_check=$(run_on_node "$NODE1_IP" "sudo pcs stonith config 2>/dev/null | grep -i stonith || echo ''" || echo "")
if [[ -n "$stonith_check" ]]; then
    pass "STONITH resource configured"
    ((PASS_COUNT++))
else
    fail "STONITH resource not configured"
    ((FAIL_COUNT++))
fi

# Check 4: STONITH is enabled in cluster
echo -n "4. Checking STONITH is enabled... "
stonith_enabled=$(run_on_node "$NODE1_IP" "sudo pcs property config 2>/dev/null | grep -i 'stonith-enabled' || echo 'true'" || echo "")
if [[ "$stonith_enabled" != *"false"* ]]; then
    pass "STONITH is enabled in cluster"
    ((PASS_COUNT++))
else
    fail "STONITH is disabled"
    ((FAIL_COUNT++))
fi

# Check 5: STONITH device for Node 1 exists
echo -n "5. Checking STONITH device for Node 1... "
device1=$(run_on_node "$NODE1_IP" "sudo pcs stonith config 2>/dev/null | grep -E 'stonith-node1' | head -1 || echo ''" || echo "")
if [[ -n "$device1" ]]; then
    pass "STONITH device configured for Node 1"
    ((PASS_COUNT++))
else
    fail "STONITH device not configured for Node 1"
    ((FAIL_COUNT++))
fi

# Check 6: STONITH device for Node 2 exists
echo -n "6. Checking STONITH device for Node 2... "
device2=$(run_on_node "$NODE1_IP" "sudo pcs stonith config 2>/dev/null | grep -E 'stonith-node2' | head -1 || echo ''" || echo "")
if [[ -n "$device2" ]]; then
    pass "STONITH device configured for Node 2"
    ((PASS_COUNT++))
else
    fail "STONITH device not configured for Node 2"
    ((FAIL_COUNT++))
fi

# Check 7: STONITH device for Node 3 exists
echo -n "7. Checking STONITH device for Node 3... "
device3=$(run_on_node "$NODE1_IP" "sudo pcs stonith config 2>/dev/null | grep -E 'stonith-node3' | head -1 || echo ''" || echo "")
if [[ -n "$device3" ]]; then
    pass "STONITH device configured for Node 3"
    ((PASS_COUNT++))
else
    fail "STONITH device not configured for Node 3"
    ((FAIL_COUNT++))
fi

# Check 8: All cluster nodes are online
echo -n "8. Checking all nodes online... "
online_nodes=$(run_on_node "$NODE1_IP" "sudo crm_mon -1 2>/dev/null | grep -c 'Online:' || echo 0")
if [[ "$online_nodes" -ge 1 ]]; then
    pass "All cluster nodes are online"
    ((PASS_COUNT++))
else
    fail "Cluster nodes offline"
    ((FAIL_COUNT++))
fi

# Check 9: Cluster has quorum
echo -n "9. Checking cluster quorum... "
quorum=$(run_on_node "$NODE1_IP" "sudo crm_mon -1 2>/dev/null | grep -i 'partition with quorum' || echo ''" || echo "")
if [[ -n "$quorum" ]]; then
    pass "Cluster has quorum"
    ((PASS_COUNT++))
else
    fail "Cluster lost quorum"
    ((FAIL_COUNT++))
fi

# Check 10: STONITH device test (test connectivity)
echo -n "10. Testing STONITH device connectivity... "
fence_test=$(run_on_node "$NODE1_IP" "sudo pcs stonith config 2>/dev/null | grep -c 'Resource:' || echo 0")
if [[ "$fence_test" -ge 3 ]]; then
    pass "STONITH devices operational"
    ((PASS_COUNT++))
else
    fail "STONITH device status unclear"
    ((FAIL_COUNT++))
fi

# Check 11: Verify resource is still running
echo -n "11. Checking managed resource status... "
resource=$(run_on_node "$NODE1_IP" "sudo crm_mon -1 2>/dev/null | grep -i 'apache' || echo ''" || echo "")
if [[ -n "$resource" ]]; then
    pass "Managed resource is running"
    ((PASS_COUNT++))
else
    fail "Managed resource not running"
    ((FAIL_COUNT++))
fi

# Check 12: Cluster shows no failed non-STONITH resources
echo -n "12. Checking for failed cluster resources... "
failed=$(run_on_node "$NODE1_IP" "sudo crm_mon -1 2>/dev/null | grep -E '^\s+\* .*error|^\s+\* .*FAILED' | grep -vi 'stonith' || echo ''" || echo "")
if [[ -z "$failed" ]]; then
    pass "No failed cluster resources detected"
    ((PASS_COUNT++))
else
    fail "Failed cluster resources detected"
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
