#!/bin/bash
source /opt/linux-labs/lib/colors.sh
rc=0

[ -d /tmp/data ] && pass "/tmp/data exists" || { fail "/tmp/data missing"; rc=1; }
[ -f /tmp/data/info.txt ] && pass "info.txt exists" || { fail "info.txt missing"; rc=1; }
grep -q hello /tmp/data/info.txt 2>/dev/null && pass "contains hello" || { fail "missing hello"; rc=1; }

exit $rc

