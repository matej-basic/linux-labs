#!/bin/bash

source /opt/linux-labs/lib/colors.sh

passcount=0
failcount=0

ok()   { pass "$*"; ((passcount++)); }
err()  { fail "$*"; ((failcount++)); }

# Check if enabled
if systemctl is-enabled test-service.service >/dev/null 2>&1; then
    ok "test-service.service is enabled"
else
    err "test-service.service is enabled"
fi

# Check if running
if systemctl is-active test-service.service >/dev/null 2>&1; then
    ok "test-service.service is running"
else
    err "test-service.service is running"
fi

echo ""
echo "Results: $passcount passed, $failcount failed"

if [[ $failcount -eq 0 ]]; then
    pass "Lab completed successfully"
    exit 0
else
    fail "Lab incomplete"
    exit 1
fi
