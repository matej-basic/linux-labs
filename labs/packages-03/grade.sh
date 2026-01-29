#!/bin/bash
source /opt/linux-labs/lib/colors.sh
rc=0

passcount=0
failcount=0

pass() { echo -e "${GREEN}PASS${RESET}: $*"; ((++passcount)); }
fail() { echo -e "${RED}NO PASS${RESET}: $*"; ((++failcount)); }

rpm -q curl &>/dev/null && pass "curl package is installed" || { fail "curl package not installed"; rc=1; }
[ -f /tmp/curl-files.txt ] && pass "/tmp/curl-files.txt exists" || { fail "/tmp/curl-files.txt not found"; rc=1; }
grep -q "/usr/bin/curl" /tmp/curl-files.txt && pass "curl binary found in file list" || { fail "/usr/bin/curl not in file list"; rc=1; }
[ $(wc -l < /tmp/curl-files.txt) -gt 0 ] && pass "File list is not empty" || { fail "File list is empty"; rc=1; }

# Compare /tmp/curl-files.txt with rpm -ql curl output
if diff -q <(rpm -ql curl | sort) <(sort /tmp/curl-files.txt) &>/dev/null; then
    pass "/tmp/curl-files.txt matches rpm -ql curl output"
else
    fail "/tmp/curl-files.txt does not match rpm -ql curl output"
    rc=1
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

