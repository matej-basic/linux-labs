#!/bin/bash
source /opt/linux-labs/lib/colors.sh
rc=0

passcount=0
failcount=0

pass() { echo -e "${GREEN}PASS${RESET}: $*"; ((passcount++)); }
fail() { echo -e "${RED}NO PASS${RESET}: $*"; ((failcount++)); }

[ -d /tmp/data ] && pass "/tmp/data exists" || { fail "/tmp/data missing"; rc=1; }
[ -f /tmp/data/info.txt ] && pass "info.txt exists" || { fail "info.txt missing"; rc=1; }
grep -q hello /tmp/data/info.txt 2>/dev/null && pass "contains hello" || { fail "missing hello"; rc=1; }

echo ""
echo "Results: $passcount passed, $failcount failed"

if [[ $failcount -eq 0 ]]; then
	pass "Lab completed successfully"
	exit 0
else
	fail "Lab incomplete"
	exit 1
fi

