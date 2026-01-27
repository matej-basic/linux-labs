#!/bin/bash
# replication-03 - MySQL Multi-Master Replication Grading Script

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
NODE_A=$(echo "$(get_all_node_ips)" | awk '{print $1}')
NODE_B=$(echo "$(get_all_node_ips)" | awk '{print $2}')
NODE_C=$(echo "$(get_all_node_ips)" | awk '{print $3}')

echo "Checking Node A: $NODE_A"
echo "Checking Node B: $NODE_B"
echo "Checking Node C: $NODE_C"
echo ""

# Check 1-3: MySQL running on all nodes
for i in 1 2 3; do
    eval "node_ip=\$NODE_$(printf \\$(printf '%03o' $((65+i-1))))"
    echo -n "$i. Checking MySQL on node $((i)): $node_ip... "
    if run_on_node "$node_ip" "sudo systemctl is-active mysqld > /dev/null 2>&1"; then
        pass "MySQL running"
        ((PASS_COUNT++))
    else
        fail "MySQL not running"
        ((FAIL_COUNT++))
    fi
done

# Check 4-6: Binary logging on all nodes
for i in 1 2 3; do
    eval "node_ip=\$NODE_$(printf \\$(printf '%03o' $((65+i-1))))"
    echo -n "$((i+3)). Checking binary logging on node $((i)): $node_ip... "
    binlog=$(run_on_node "$node_ip" "sudo mysql -u root  -e \"SHOW VARIABLES LIKE 'log_bin';\" 2>/dev/null" | grep -i "ON" || echo "")
    if [[ -n "$binlog" ]]; then
        pass "Binary logging enabled"
        ((PASS_COUNT++))
    else
        fail "Binary logging not enabled"
        ((FAIL_COUNT++))
    fi
done

# Check 7: Node A replicates to B
echo -n "7. Checking A→B replication... "
slave_status=$(run_on_node "$NODE_B" "sudo mysql -u root  -e \"SHOW SLAVE STATUS\\G\" 2>/dev/null" | grep -i "Master_Host" || echo "")
if [[ -n "$slave_status" ]]; then
    pass "Node B configured as slave of Node A"
    ((PASS_COUNT++))
else
    fail "Node B not configured as slave of Node A"
    ((FAIL_COUNT++))
fi

# Check 8: Node B replicates to C
echo -n "8. Checking B→C replication... "
slave_status=$(run_on_node "$NODE_C" "sudo mysql -u root  -e \"SHOW SLAVE STATUS\\G\" 2>/dev/null" | grep -i "Master_Host" || echo "")
if [[ -n "$slave_status" ]]; then
    pass "Node C configured as slave of Node B"
    ((PASS_COUNT++))
else
    fail "Node C not configured as slave of Node B"
    ((FAIL_COUNT++))
fi

# Check 9: Node C replicates to A
echo -n "9. Checking C→A replication... "
slave_status=$(run_on_node "$NODE_A" "sudo mysql -u root  -e \"SHOW SLAVE STATUS\\G\" 2>/dev/null" | grep -i "Master_Host" || echo "")
if [[ -n "$slave_status" ]]; then
    pass "Node A configured as slave of Node C"
    ((PASS_COUNT++))
else
    fail "Node A not configured as slave of Node C"
    ((FAIL_COUNT++))
fi

# Check 10: Test circular replication
echo -n "10. Testing circular replication... "
test_db="mm_test_$RANDOM"
test_ok=0

# Create on Node A
run_on_node "$NODE_A" "sudo mysql -u root  -e \"CREATE DATABASE $test_db;\" 2>/dev/null" > /dev/null 2>&1 || true
sleep 3

# Check on Node B and C
b_exists=$(run_on_node "$NODE_B" "sudo mysql -u root  -e \"SHOW DATABASES LIKE '$test_db';\" 2>/dev/null" | grep "$test_db" || echo "")
c_exists=$(run_on_node "$NODE_C" "sudo mysql -u root  -e \"SHOW DATABASES LIKE '$test_db';\" 2>/dev/null" | grep "$test_db" || echo "")

if [[ -n "$b_exists" ]] && [[ -n "$c_exists" ]]; then
    pass "Circular replication working (A→B and A→C)"
    ((PASS_COUNT++))
    test_ok=1
    # Clean up
    run_on_node "$NODE_A" "sudo mysql -u root  -e \"DROP DATABASE $test_db;\" 2>/dev/null" > /dev/null 2>&1 || true
else
    fail "Circular replication not working"
    ((FAIL_COUNT++))
fi

echo ""
echo "════════════════════════════════════════════════"
echo "Results: $PASS_COUNT passed, $FAIL_COUNT failed"
echo "════════════════════════════════════════════════"

if [[ $FAIL_COUNT -eq 0 ]]; then
    exit 0
else
    exit 1
fi
