#!/bin/bash
source /opt/linux-labs/lib/colors.sh
rc=0

passcount=0
failcount=0

pass() { echo -e "${GREEN}PASS${RESET}: $*"; ((passcount++)); }
fail() { echo -e "${RED}NO PASS${RESET}: $*"; ((failcount++)); }

TEAM_OR_BOND=""
if nmcli connection show team0 &>/dev/null; then
    TEAM_OR_BOND="team0"
    pass "team0 interface exists"
elif nmcli connection show bond0 &>/dev/null; then
    TEAM_OR_BOND="bond0"
    pass "bond0 interface exists"
else
    fail "team0 or bond0 not found"
    rc=1
fi

if [ -n "$TEAM_OR_BOND" ]; then
    ip addr show "$TEAM_OR_BOND" 2>/dev/null | grep -q "192.168.100.1/24" && pass "IP 192.168.100.1/24 on $TEAM_OR_BOND" || { fail "IP 192.168.100.1/24 not found"; rc=1; }
    
    if [ "$TEAM_OR_BOND" = "team0" ]; then
        (nmcli connection show team0-eth0 &>/dev/null || nmcli connection show team0-eth1 &>/dev/null) && pass "team0 slave interfaces configured" || { fail "team0 slaves missing"; rc=1; }
    else
        (nmcli connection show bond0-eth0 &>/dev/null || nmcli connection show bond0-eth1 &>/dev/null) && pass "bond0 slave interfaces configured" || { fail "bond0 slaves missing"; rc=1; }
    fi
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
