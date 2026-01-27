#!/bin/bash
# replication-02 - PostgreSQL Streaming Replication Grading Script

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
PRIMARY_IP=$(echo "$(get_all_node_ips)" | awk '{print $1}')
STANDBY1_IP=$(echo "$(get_all_node_ips)" | awk '{print $2}')

echo "Checking primary: $PRIMARY_IP"
echo "Checking standby: $STANDBY1_IP"
echo ""

# Check 1: Primary PostgreSQL running
echo -n "1. Checking primary PostgreSQL service... "
if run_on_node "$PRIMARY_IP" "sudo systemctl is-active postgresql > /dev/null 2>&1"; then
    pass "PostgreSQL service running on primary"
    ((PASS_COUNT++))
else
    fail "PostgreSQL service not running on primary"
    ((FAIL_COUNT++))
fi

# Check 2: Standby PostgreSQL running
echo -n "2. Checking standby PostgreSQL service... "
if run_on_node "$STANDBY1_IP" "sudo systemctl is-active postgresql > /dev/null 2>&1"; then
    pass "PostgreSQL service running on standby"
    ((PASS_COUNT++))
else
    fail "PostgreSQL service not running on standby"
    ((FAIL_COUNT++))
fi

# Check 3: Primary has max_wal_senders set
echo -n "3. Checking primary replication configuration... "
wal_senders=$(run_on_node "$PRIMARY_IP" "cd /tmp && sudo -u postgres psql -t -c \"SHOW max_wal_senders;\" 2>/dev/null" | tr -d ' ' || echo "0")
if [[ "$wal_senders" != "0" ]] && [[ "$wal_senders" -gt 0 ]]; then
    pass "Primary configured for streaming replication (max_wal_senders=$wal_senders)"
    ((PASS_COUNT++))
else
    fail "Primary not configured for streaming replication"
    ((FAIL_COUNT++))
fi

# Check 4: Replication user exists on primary
echo -n "4. Checking replication user on primary... "
repl_user=$(run_on_node "$PRIMARY_IP" "cd /tmp && sudo -u postgres psql -t -c \"SELECT usename FROM pg_user WHERE usename='repl';\" 2>/dev/null" | tr -d ' ' || echo "")
if [[ "$repl_user" == "repl" ]]; then
    pass "Replication user 'repl' exists on primary"
    ((PASS_COUNT++))
else
    fail "Replication user 'repl' not found on primary"
    ((FAIL_COUNT++))
fi

# Check 5: Standby is in recovery mode
echo -n "5. Checking standby recovery status... "
recovery=$(run_on_node "$STANDBY1_IP" "cd /tmp && sudo -u postgres psql -t -c \"SELECT pg_is_in_recovery();\" 2>/dev/null" | tr -d ' ' || echo "f")
if [[ "$recovery" == "t" ]]; then
    pass "Standby is in recovery mode"
    ((PASS_COUNT++))
else
    fail "Standby is not in recovery mode"
    ((FAIL_COUNT++))
fi

# Check 6: Standby connected to primary
echo -n "6. Checking replication connection... "
wal_receivers=$(run_on_node "$STANDBY1_IP" "cd /tmp && sudo -u postgres psql -t -c \"SELECT COUNT(*) FROM pg_stat_wal_receiver;\" 2>/dev/null" | tr -d ' ' || echo "0")
if [[ "$wal_receivers" != "0" ]] && [[ "$wal_receivers" -gt 0 ]]; then
    pass "Standby connected to primary via streaming replication"
    ((PASS_COUNT++))
else
    fail "Standby not connected to primary"
    ((FAIL_COUNT++))
fi

# Check 7: Test data replication
echo -n "7. Testing data replication... "
test_table="repl_test_$RANDOM"
# Create test table on primary
run_on_node "$PRIMARY_IP" "cd /tmp && sudo -u postgres psql -c \"CREATE TABLE $test_table (id SERIAL PRIMARY KEY, data TEXT);\" 2>/dev/null" > /dev/null 2>&1 || true
run_on_node "$PRIMARY_IP" "cd /tmp && sudo -u postgres psql -c \"INSERT INTO $test_table (data) VALUES ('test_data_replication');\" 2>/dev/null" > /dev/null 2>&1 || true
sleep 2
# Check if table exists on standby
standby_table=$(run_on_node "$STANDBY1_IP" "cd /tmp && sudo -u postgres psql -t -c \"SELECT COUNT(*) FROM $test_table;\" 2>/dev/null" | tr -d ' ' || echo "0")
if [[ "$standby_table" != "0" ]]; then
    pass "Data replicated from primary to standby"
    ((PASS_COUNT++))
    # Clean up
    run_on_node "$PRIMARY_IP" "cd /tmp && sudo -u postgres psql -c \"DROP TABLE $test_table;\" 2>/dev/null" > /dev/null 2>&1 || true
else
    fail "Data not replicated from primary to standby"
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
