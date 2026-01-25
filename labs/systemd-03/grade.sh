#!/bin/bash

source /opt/linux-labs/lib/colors.sh

passcount=0
failcount=0

ok()   { pass "$*"; ((passcount++)); }
err()  { fail "$*"; ((failcount++)); }

# Check unit files exist
if [[ -f /etc/systemd/system/lab-worker.service ]]; then
    ok "lab-worker.service unit file exists"
else
    err "lab-worker.service unit file exists"
fi

if [[ -f /etc/systemd/system/lab-timer.timer ]]; then
    ok "lab-timer.timer unit file exists"
else
    err "lab-timer.timer unit file exists"
fi

if [[ -f /etc/systemd/system/lab-timer.service ]]; then
    ok "lab-timer.service unit file exists"
else
    err "lab-timer.service unit file exists"
fi

# Check if timer is enabled
if systemctl is-enabled lab-timer.timer >/dev/null 2>&1; then
    ok "lab-timer.timer is enabled"
else
    err "lab-timer.timer is enabled"
fi

# Check if timer is active
if systemctl is-active lab-timer.timer >/dev/null 2>&1; then
    ok "lab-timer.timer is active"
else
    err "lab-timer.timer is active"
fi

# Check Type=oneshot
if grep -q "^Type=oneshot" /etc/systemd/system/lab-timer.service 2>/dev/null; then
    ok "lab-timer.service has Type=oneshot"
else
    err "lab-timer.service has Type=oneshot"
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
