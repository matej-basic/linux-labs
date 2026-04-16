#!/bin/bash
# clustering-03 - Advanced Cluster Protection Grading Script

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
echo -n "1. Checking cluster status... "
if run_on_node "$NODE1_IP" "sudo systemctl is-active pacemaker > /dev/null 2>&1"; then
    pass "Cluster is running"
    ((PASS_COUNT++))
else
    fail "Cluster not running"
    ((FAIL_COUNT++))
fi

# Check 2: All 3 nodes are online
echo -n "2. Checking all 3 nodes online... "
nodes=$(run_on_node "$NODE1_IP" "sudo crm_node -l 2>/dev/null | grep -c 'member' || echo 0")
if [[ "$nodes" -ge 3 ]]; then
    pass "All 3 nodes online"
    ((PASS_COUNT++))
else
    fail "Not all 3 nodes online"
    ((FAIL_COUNT++))
fi

# Check 3: Cluster has quorum
echo -n "3. Checking cluster quorum... "
quorum=$(run_on_node "$NODE1_IP" "sudo crm_mon -1 2>/dev/null | grep -i 'partition with quorum' || echo ''" || echo "")
if [[ -n "$quorum" ]]; then
    pass "Cluster has quorum"
    ((PASS_COUNT++))
else
    fail "Cluster lost quorum"
    ((FAIL_COUNT++))
fi

# Check 4: Expected votes is set to 3
echo -n "4. Checking expected votes = 3... "
votes=$(run_on_node "$NODE1_IP" "sudo corosync-quorumtool 2>/dev/null | grep 'Expected votes' || echo ''" || echo "")
if [[ "$votes" == *"3"* ]]; then
    pass "Expected votes set to 3"
    ((PASS_COUNT++))
else
    fail "Expected votes not set correctly"
    ((FAIL_COUNT++))
fi

# Check 5: Quorum provider is votequorum
echo -n "5. Checking votequorum provider... "
provider=$(run_on_node "$NODE1_IP" "sudo grep -i 'provider: corosync_votequorum' /etc/corosync/corosync.conf || echo ''" || echo "")
if [[ -n "$provider" ]]; then
    pass "Votequorum provider configured"
    ((PASS_COUNT++))
else
    fail "Votequorum provider not configured"
    ((FAIL_COUNT++))
fi

# Check 6: Ring topology configured
echo -n "6. Checking ring topology... "
ring=$(run_on_node "$NODE1_IP" "sudo grep -i 'ringnumber' /etc/corosync/corosync.conf || echo ''" || echo "")
if [[ -n "$ring" ]]; then
    pass "Ring topology configured"
    ((PASS_COUNT++))
else
    fail "Ring topology not configured"
    ((FAIL_COUNT++))
fi

# Check 7: Two-node mode is disabled
echo -n "7. Checking two_node is disabled... "
two_node=$(run_on_node "$NODE1_IP" "sudo grep 'two_node: 0' /etc/corosync/corosync.conf || echo ''" || echo "")
if [[ -n "$two_node" ]]; then
    pass "two_node mode disabled"
    ((PASS_COUNT++))
else
    fail "two_node mode not disabled"
    ((FAIL_COUNT++))
fi

# Check 8: Autofencing is enabled
echo -n "8. Checking autofencing... "
autofence=$(run_on_node "$NODE1_IP" "sudo grep -i 'autofencing' /etc/corosync/corosync.conf || echo ''" || echo "")
if [[ -n "$autofence" ]]; then
    pass "Autofencing is enabled"
    ((PASS_COUNT++))
else
    fail "Autofencing not enabled"
    ((FAIL_COUNT++))
fi

# Check 9: STONITH is still enabled
echo -n "9. Checking STONITH still enabled... "
stonith=$(run_on_node "$NODE1_IP" "sudo pcs property config 2>/dev/null | grep 'stonith-enabled' || echo ''" || echo "")
if [[ -n "$stonith" && "$stonith" != *"false"* ]]; then
    pass "STONITH still enabled"
    ((PASS_COUNT++))
else
    fail "STONITH not properly configured"
    ((FAIL_COUNT++))
fi

# Check 10: Cluster shows no split-brain
echo -n "10. Checking no split-brain conditions... "
splitbrain=$(run_on_node "$NODE1_IP" "sudo crm_mon -1 2>/dev/null | grep -i 'split' || echo ''" || echo "")
if [[ -z "$splitbrain" ]]; then
    pass "No split-brain detected"
    ((PASS_COUNT++))
else
    fail "Split-brain condition detected"
    ((FAIL_COUNT++))
fi

# Check 11: Cluster can reach all nodes
echo -n "11. Checking node reachability... "
reach=$(run_on_node "$NODE1_IP" "sudo crm_node -l 2>/dev/null | grep -c 'member' || echo 0")
if [[ "$reach" -ge 3 ]]; then
    pass "All nodes are reachable"
    ((PASS_COUNT++))
else
    fail "Node reachability issue"
    ((FAIL_COUNT++))
fi

# Check 12: Managed resources are running
echo -n "12. Checking managed resources... "
resources=$(run_on_node "$NODE1_IP" "sudo crm_mon -1 2>/dev/null | grep -E 'Started|running' | wc -l || echo 0")
if [[ "$resources" -ge 1 ]]; then
    pass "Managed resources are running"
    ((PASS_COUNT++))
else
    fail "No managed resources found"
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
