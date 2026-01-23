#!/bin/bash
source /opt/linux-labs/lib/colors.sh
rc=0

nmcli connection show labnet-static &>/dev/null && pass "Connection 'labnet-static' exists" || { fail "Connection 'labnet-static' missing"; rc=1; }
ip addr show | grep -q "192.168.1.100" && pass "IP 192.168.1.100 configured" || { fail "IP 192.168.1.100 not found"; rc=1; }
ip addr show | grep "192.168.1.100" | grep -q "/24" && pass "Netmask /24 configured" || { fail "Netmask /24 not found"; rc=1; }
nmcli connection show labnet-static | grep -q "192.168.1.1" && pass "Gateway 192.168.1.1 configured" || { fail "Gateway 192.168.1.1 not found"; rc=1; }
nmcli connection show labnet-static | grep -q "8.8.8.8" && pass "DNS 8.8.8.8 configured" || { fail "DNS 8.8.8.8 not found"; rc=1; }

exit $rc
