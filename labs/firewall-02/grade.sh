#!/bin/bash
source /opt/linux-labs/lib/colors.sh
rc=0

passcount=0
failcount=0

pass() { echo -e "${GREEN}PASS${RESET}: $*"; ((++passcount)); }
fail() { echo -e "${RED}NO PASS${RESET}: $*"; ((++failcount)); }

# Check if the rich rule exists for port 443 from 192.168.1.0/24
firewall-cmd --list-rich-rules --zone=public 2>/dev/null | grep -q 'source address="192.168.1.0/24".*port="443"' && \
  pass "Rich rule for port 443 from 192.168.1.0/24 exists" || \
  { fail "Rich rule for port 443 from 192.168.1.0/24 not found"; rc=1; }

# Check if trusted zone has an interface assigned
get_active_zones=$(firewall-cmd --get-active-zones 2>/dev/null)
echo "$get_active_zones" | grep -A 5 "trusted" | grep -qE "(eth|ens)" && \
  pass "Trusted zone has an interface assigned" || \
  { fail "Trusted zone interface assignment not found"; rc=1; }

# Verify firewalld is running
systemctl is-active firewalld &>/dev/null && \
  pass "Firewalld service is running" || \
  { fail "Firewalld service is not running"; rc=1; }

# Verify the rich rule is persistent (exists in permanent config)
firewall-cmd --permanent --list-rich-rules --zone=public 2>/dev/null | grep -q 'source address="192.168.1.0/24".*port="443"' && \
  pass "Rich rule is permanently configured" || \
  { fail "Rich rule is not permanently configured"; rc=1; }

echo ""
echo "Results: $passcount passed, $failcount failed"

if [[ $failcount -eq 0 ]]; then
  pass "Lab completed successfully"
  exit 0
else
  fail "Lab incomplete"
  exit 1
fi

