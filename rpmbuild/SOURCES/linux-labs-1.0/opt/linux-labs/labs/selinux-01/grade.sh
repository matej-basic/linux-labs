#!/bin/bash
source /opt/linux-labs/lib/colors.sh
rc=0

# Check if SELinux tools are available
if ! command -v getenforce >/dev/null 2>&1; then
    fail "SELinux tools not installed (install selinux-policy-*)"
    exit 1
fi

# Check /etc/selinux/config exists
if [ ! -f /etc/selinux/config ]; then
    fail "/etc/selinux/config missing"
    rc=1
fi

# Check current runtime mode is enforcing
current_mode=$(getenforce 2>/dev/null)
if [ "$current_mode" = "Enforcing" ]; then
    pass "Current mode: Enforcing"
else
    fail "Current mode not Enforcing (got: $current_mode)"
    rc=1
fi

# Check /etc/selinux/config has SELINUX=enforcing
if grep -q "^SELINUX=enforcing" /etc/selinux/config; then
    pass "/etc/selinux/config set to enforcing"
else
    fail "/etc/selinux/config not set to enforcing"
    rc=1
fi

# Check SELinux policy is loaded
if sestatus 2>/dev/null | grep -q "SELinux status"; then
    pass "SELinux is enabled"
else
    fail "SELinux status check failed"
    rc=1
fi

# Check policy type (should be targeting or similar)
policy=$(sestatus 2>/dev/null | grep "Loaded policy" | awk '{print $NF}')
if [ -n "$policy" ]; then
    pass "SELinux policy: $policy"
else
    fail "Could not determine loaded policy"
    rc=1
fi

exit $rc
