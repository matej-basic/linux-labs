#!/bin/bash
source /opt/linux-labs/lib/colors.sh
rc=0

passcount=0
failcount=0

pass() { echo -e "${GREEN}PASS${RESET}: $*"; ((passcount++)); }
fail() { echo -e "${RED}NO PASS${RESET}: $*"; ((failcount++)); }

nmcli connection show vlan10 &>/dev/null && pass "Connection 'vlan10' exists" || { fail "Connection 'vlan10' missing"; rc=1; }
ip link show vlan10 &>/dev/null && pass "VLAN interface vlan10 exists" || { fail "VLAN interface vlan10 missing"; rc=1; }
ip addr show vlan10 2>/dev/null | grep -q "192.168.10.1/24" && pass "IP 192.168.10.1/24 on vlan10" || { fail "IP 192.168.10.1/24 not found"; rc=1; }
[ "$(hostname)" = "labhost" ] || [ "$(hostnamectl --static)" = "labhost" ] && pass "Hostname is labhost" || { fail "Hostname not set to labhost"; rc=1; }
grep -q "labhost.example.com" /etc/hosts && pass "FQDN labhost.example.com in /etc/hosts" || { fail "FQDN not in /etc/hosts"; rc=1; }

echo ""
echo "Results: $passcount passed, $failcount failed"

if [[ $failcount -eq 0 ]]; then
	pass "Lab completed successfully"
	exit 0
else
	fail "Lab incomplete"
	exit 1
fi
