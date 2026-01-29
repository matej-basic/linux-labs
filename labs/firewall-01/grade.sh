#!/bin/bash
source /opt/linux-labs/lib/colors.sh
rc=0

passcount=0
failcount=0

pass() { echo -e "${GREEN}PASS${RESET}: $*"; ((++passcount)); }
fail() { echo -e "${RED}NO PASS${RESET}: $*"; ((++failcount)); }

# Check if HTTP service is enabled in public zone
firewall-cmd --query-service=http --zone=public &>/dev/null && \
  pass "HTTP service is enabled in public zone" || \
  { fail "HTTP service not found in public zone"; rc=1; }

# Check if port 8080/tcp is open in public zone
firewall-cmd --list-ports --zone=public 2>/dev/null | grep -q "8080/tcp" && \
  pass "Port 8080/tcp is open in public zone" || \
  { fail "Port 8080/tcp not found in public zone"; rc=1; }

# Verify firewalld is running
systemctl is-active firewalld &>/dev/null && \
  pass "Firewalld service is running" || \
  { fail "Firewalld service is not running"; rc=1; }

echo ""
echo "Results: $passcount passed, $failcount failed"

if [[ $failcount -eq 0 ]]; then
  pass "Lab completed successfully"
  exit 0
else
  fail "Lab incomplete"
  exit 1
fi

