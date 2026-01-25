#!/bin/bash

source /opt/linux-labs/lib/colors.sh

passcount=0
failcount=0

ok()   { pass "$*"; ((passcount++)); }
err()  { fail "$*"; ((failcount++)); }

# Check unit file exists
if [[ -f /etc/systemd/system/custom-app.service ]]; then
    ok "custom-app.service unit file exists"
else
    err "custom-app.service unit file exists"
fi

# Check if enabled
if systemctl is-enabled custom-app.service >/dev/null 2>&1; then
    ok "custom-app.service is enabled"
else
    err "custom-app.service is enabled"
fi

# Check if running
if systemctl is-active custom-app.service >/dev/null 2>&1; then
    ok "custom-app.service is running"
else
    err "custom-app.service is running"
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
