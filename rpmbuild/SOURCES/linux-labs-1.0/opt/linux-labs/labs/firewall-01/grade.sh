#!/bin/bash
source /opt/linux-labs/lib/colors.sh
rc=0

# Check if HTTP service is enabled in public zone
firewall-cmd --list-services --zone=public 2>/dev/null | grep -q http && \
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

exit $rc

