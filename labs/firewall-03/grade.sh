#!/bin/bash
source /opt/linux-labs/lib/colors.sh
rc=0

passcount=0
failcount=0

pass() { echo -e "${GREEN}PASS${RESET}: $*"; ((passcount++)); }
fail() { echo -e "${RED}NO PASS${RESET}: $*"; ((failcount++)); }

# Check if masquerading is enabled on internal zone
firewall-cmd --permanent --zone=internal --query-masquerade 2>/dev/null && \
  pass "Masquerading is enabled on internal zone" || \
  { fail "Masquerading not enabled on internal zone"; rc=1; }

# Check if port forwarding 8443->443 exists on public zone
firewall-cmd --permanent --zone=public --list-forward-ports 2>/dev/null | grep -q "port=8443:proto=tcp:toport=443" && \
  pass "Port forwarding 8443->443 is configured on public zone" || \
  { fail "Port forwarding 8443->443 not found on public zone"; rc=1; }

# Check if custom-app service exists
[ -f /etc/firewalld/services/custom-app.xml ] && \
  pass "Custom service definition file exists" || \
  { fail "Custom service definition file not found"; rc=1; }

# Check if custom-app service is added to public zone
firewall-cmd --permanent --zone=public --list-services 2>/dev/null | grep -q "custom-app" && \
  pass "Custom-app service is added to public zone" || \
  { fail "Custom-app service not found in public zone"; rc=1; }

# Check if HTTP service is in public zone
firewall-cmd --permanent --zone=public --list-services 2>/dev/null | grep -q "http" && \
  pass "HTTP service is in public zone" || \
  { fail "HTTP service not found in public zone"; rc=1; }

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

