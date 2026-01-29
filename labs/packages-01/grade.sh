#!/bin/bash
source /opt/linux-labs/lib/colors.sh
rc=0

passcount=0
failcount=0

pass() { echo -e "${GREEN}PASS${RESET}: $*"; ((++passcount)); }
fail() { echo -e "${RED}NO PASS${RESET}: $*"; ((++failcount)); }

rpm -q git &>/dev/null && pass "git package is installed" || { fail "git package not installed"; rc=1; }
which git &>/dev/null && pass "git command is available" || { fail "git command not found"; rc=1; }
dnf list --installed &>/dev/null && pass "dnf list --installed works" || { fail "dnf list --installed failed"; rc=1; }

echo ""
echo "Results: $passcount passed, $failcount failed"

if [[ $failcount -eq 0 ]]; then
	pass "Lab completed successfully"
	exit 0
else
	fail "Lab incomplete"
	exit 1
fi

