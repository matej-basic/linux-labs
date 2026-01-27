#!/bin/bash
# replication-01 - MySQL Master-Slave Replication Grading Script

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

if [[ "$NODE_COUNT" -lt 2 ]]; then
    fail "Lab requires at least 2 nodes (current: $NODE_COUNT)"
    ((FAIL_COUNT++))
    exit 1
fi

# Get node IPs
MASTER_IP=$(echo "$(get_all_node_ips)" | awk '{print $1}')
SLAVE_IP=$(echo "$(get_all_node_ips)" | awk '{print $2}')

echo "Checking master: $MASTER_IP"
echo "Checking slave: $SLAVE_IP"
echo ""

# Check 1: Master has MySQL running
echo -n "1. Checking master MySQL service... "
if run_on_node "$MASTER_IP" "sudo systemctl is-active mysqld > /dev/null 2>&1"; then
    pass "MySQL service running on master"
    ((PASS_COUNT++))
else
    fail "MySQL service not running on master"
    ((FAIL_COUNT++))
fi

# Check 2: Slave has MySQL running
echo -n "2. Checking slave MySQL service... "
if run_on_node "$SLAVE_IP" "sudo systemctl is-active mysqld > /dev/null 2>&1"; then
    pass "MySQL service running on slave"
    ((PASS_COUNT++))
else
    fail "MySQL service not running on slave"
    ((FAIL_COUNT++))
fi

# Check 3: Master has binary logging enabled
echo -n "3. Checking master binary logging... "
binlog_check=$(run_on_node "$MASTER_IP" "sudo mysql -u root -e \"SHOW VARIABLES LIKE 'log_bin';\" 2>/dev/null" | grep -i "ON" || echo "")
if [[ -n "$binlog_check" ]]; then
    pass "Binary logging enabled on master"
    ((PASS_COUNT++))
else
    fail "Binary logging not enabled on master"
    ((FAIL_COUNT++))
fi

# Check 4: Replication user exists on master
echo -n "4. Checking replication user on master... "
user_check=$(run_on_node "$MASTER_IP" "sudo mysql -u root -e \"SELECT User FROM mysql.user WHERE User='repl';\" 2>/dev/null" | grep -i "repl" || echo "")
if [[ -n "$user_check" ]]; then
    pass "Replication user 'repl' exists on master"
    ((PASS_COUNT++))
else
    fail "Replication user 'repl' not found on master"
    ((FAIL_COUNT++))
fi

# Check 5: Slave is connected to master
echo -n "5. Checking slave replication status... "
slave_status=$(run_on_node "$SLAVE_IP" "sudo mysql -u root -e \"SHOW SLAVE STATUS\\G\" 2>/dev/null" | grep -i "Master_Host" || echo "")
if [[ -n "$slave_status" ]]; then
    pass "Slave configured with master connection"
    ((PASS_COUNT++))
else
    fail "Slave not configured with master connection"
    ((FAIL_COUNT++))
fi

# Check 6: Test data replication
echo -n "6. Testing data replication... "
test_db="replication_test_$RANDOM"
# Create test database on master
run_on_node "$MASTER_IP" "sudo mysql -u root -e \"CREATE DATABASE $test_db;\" 2>/dev/null" > /dev/null 2>&1 || true
sleep 2
# Check if database exists on slave
slave_db_check=$(run_on_node "$SLAVE_IP" "sudo mysql -u root -e \"SHOW DATABASES LIKE '$test_db';\" 2>/dev/null" | grep "$test_db" || echo "")
if [[ -n "$slave_db_check" ]]; then
    pass "Database replicated from master to slave"
    ((PASS_COUNT++))
    # Clean up test database
    run_on_node "$MASTER_IP" "sudo mysql -u root -e \"DROP DATABASE $test_db;\" 2>/dev/null" > /dev/null 2>&1 || true
else
    fail "Database not replicated from master to slave"
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
