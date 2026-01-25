#!/bin/bash
source /opt/linux-labs/lib/colors.sh
rc=0

passcount=0
failcount=0

pass() { echo -e "${GREEN}PASS${RESET}: $*"; ((passcount++)); }
fail() { echo -e "${RED}NO PASS${RESET}: $*"; ((failcount++)); }

dnf repolist | grep -qi "epel" && pass "EPEL repository is enabled" || { fail "EPEL repository not found"; rc=1; }
rpm -q htop &>/dev/null && pass "htop package is installed" || { fail "htop package not installed"; rc=1; }
which htop &>/dev/null && pass "htop command is available" || { fail "htop command not found"; rc=1; }

echo ""
echo "Results: $passcount passed, $failcount failed"

if [[ $failcount -eq 0 ]]; then
	pass "Lab completed successfully"
	exit 0
else
	fail "Lab incomplete"
	exit 1
fi

