#!/bin/bash
source /opt/linux-labs/lib/colors.sh
rc=0

passcount=0
failcount=0

pass() { echo -e "${GREEN}PASS${RESET}: $*"; ((passcount++)); }
fail() { echo -e "${RED}NO PASS${RESET}: $*"; ((failcount++)); }

# Anacron checks
grep -q "anacron_lab" /etc/anacrontab && pass "Anacron job found" || { fail "Anacron job missing"; rc=1; }
grep "anacron_lab" /etc/anacrontab | grep -q "anacron-task.sh" && pass "Anacron script correct" || { fail "Anacron script incorrect"; rc=1; }
[ -x /usr/local/bin/anacron-task.sh ] && pass "anacron-task.sh executable" || { fail "anacron-task.sh missing/not executable"; rc=1; }

# Persistent timer checks
[ -f /etc/systemd/system/persistent-timer.service ] && pass "persistent-timer.service exists" || { fail "persistent-timer.service missing"; rc=1; }
[ -f /etc/systemd/system/persistent-timer.timer ] && pass "persistent-timer.timer exists" || { fail "persistent-timer.timer missing"; rc=1; }
grep -q "Persistent=true" /etc/systemd/system/persistent-timer.timer && pass "Persistent=true set" || { fail "Persistent=true missing"; rc=1; }
[ -x /usr/local/bin/persistent-task.sh ] && pass "persistent-task.sh executable" || { fail "persistent-task.sh missing/not executable"; rc=1; }

# Cron environment variable checks
sudo crontab -l 2>/dev/null | grep -q "env_task" && pass "Cron env job found" || { fail "Cron env job missing"; rc=1; }

echo ""
echo "Results: $passcount passed, $failcount failed"

if [[ $failcount -eq 0 ]]; then
    pass "Lab completed successfully"
    exit 0
else
    fail "Lab incomplete"
    exit 1
fi
