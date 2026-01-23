#!/bin/bash
source /opt/linux-labs/lib/colors.sh
rc=0

[ -f /etc/systemd/system/lab-task.service ] && pass "lab-task.service exists" || { fail "lab-task.service missing"; rc=1; }
grep -q "Type=oneshot" /etc/systemd/system/lab-task.service && pass "Service has Type=oneshot" || { fail "Type=oneshot missing"; rc=1; }
grep -q "ExecStart=/usr/local/bin/lab-task.sh" /etc/systemd/system/lab-task.service && pass "ExecStart correct" || { fail "ExecStart incorrect"; rc=1; }
[ -f /etc/systemd/system/lab-task.timer ] && pass "lab-task.timer exists" || { fail "lab-task.timer missing"; rc=1; }
grep -q "OnBootSec=1min" /etc/systemd/system/lab-task.timer && pass "OnBootSec=1min set" || { fail "OnBootSec incorrect"; rc=1; }
grep -q "OnUnitActiveSec=10min" /etc/systemd/system/lab-task.timer && pass "OnUnitActiveSec=10min set" || { fail "OnUnitActiveSec incorrect"; rc=1; }
[ -x /usr/local/bin/lab-task.sh ] && pass "lab-task.sh exists and executable" || { fail "lab-task.sh missing/not executable"; rc=1; }
sudo systemctl is-enabled lab-task.timer &>/dev/null && pass "Timer enabled" || { fail "Timer not enabled"; rc=1; }
sudo systemctl is-active lab-task.timer &>/dev/null && pass "Timer running" || { fail "Timer not running"; rc=1; }

exit $rc

echo ""

if [ $FAILED -eq 0 ]; then
    pass "Lab scheduling-02: PASSED"
    exit 0
else
    fail "Lab scheduling-02: FAILED"
    exit 1
fi
