#!/bin/bash
source /opt/linux-labs/lib/colors.sh
rc=0

passcount=0
failcount=0

pass() { echo -e "${GREEN}PASS${RESET}: $*"; ((passcount++)); }
fail() { echo -e "${RED}NO PASS${RESET}: $*"; ((failcount++)); }

journalctl -u systemd-logind -n 1 &>/dev/null && pass "Filter by service (journalctl -u)" || { fail "Cannot filter by service"; rc=1; }
journalctl -p err -n 1 &>/dev/null && pass "Filter by priority (journalctl -p err)" || { fail "Cannot filter by priority"; rc=1; }
journalctl -S '1 hour ago' -n 1 &>/dev/null && pass "Filter by time (journalctl -S)" || { fail "Cannot filter by time"; rc=1; }
journalctl -u systemd-logind -p err -n 1 &>/dev/null && pass "Combine filters (service + priority)" || { fail "Cannot combine filters"; rc=1; }
journalctl -b -n 1 &>/dev/null && pass "View boot messages (journalctl -b)" || { fail "Cannot view boot messages"; rc=1; }
journalctl -p err,warning -n 1 &>/dev/null && pass "Multiple priorities (err,warning)" || { fail "Cannot filter multiple priorities"; rc=1; }

echo ""
echo "Results: $passcount passed, $failcount failed"

if [[ $failcount -eq 0 ]]; then
	pass "Lab completed successfully"
	exit 0
else
	fail "Lab incomplete"
	exit 1
fi
