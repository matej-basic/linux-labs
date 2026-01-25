#!/bin/bash
source /opt/linux-labs/lib/colors.sh
rc=0

passcount=0
failcount=0

pass() { echo -e "${GREEN}PASS${RESET}: $*"; ((passcount++)); return 0; }
fail() { echo -e "${RED}NO PASS${RESET}: $*"; ((failcount++)); return 1; }

[ -d /var/log/journal ] && pass "Persistent journal directory exists" || { fail "/var/log/journal not found"; rc=1; }
journalctl --disk-usage &>/dev/null && pass "Can query journal disk usage" || { fail "Cannot access journal"; rc=1; }
[ "$(journalctl --list-boots 2>/dev/null | wc -l)" -gt 0 ] && pass "Can list boot sessions" || { fail "Cannot list boots"; rc=1; }
journalctl -b -n 1 &>/dev/null && pass "Can query current boot" || { fail "Cannot query current boot"; rc=1; }
systemd-analyze time &>/dev/null && pass "systemd-analyze works" || { fail "systemd-analyze failed"; rc=1; }
[ -f /etc/systemd/system/labtest-fail.service ] && pass "Test service unit file exists" || { fail "Service file not found"; rc=1; }
journalctl -u labtest-fail.service &>/dev/null && pass "Can query service in journal" || { fail "Cannot query service journal"; rc=1; }
systemctl is-active --quiet systemd-journald && pass "systemd-journald is active" || { fail "systemd-journald not running"; rc=1; }
dmesg &>/dev/null && pass "Can access kernel messages" || { fail "Cannot access dmesg"; rc=1; }

echo ""
echo "Results: $passcount passed, $failcount failed"

if [[ $failcount -eq 0 ]]; then
	pass "Lab completed successfully"
	exit 0
else
	fail "Lab incomplete"
	exit 1
fi
