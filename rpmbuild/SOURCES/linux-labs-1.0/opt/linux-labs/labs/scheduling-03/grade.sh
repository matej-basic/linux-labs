#!/bin/bash
source /opt/linux-labs/lib/colors.sh
rc=0

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

exit $rc
    
    if grep -q "Persistent=true" /etc/systemd/system/persistent-timer.timer; then
        pass "Timer has Persistent=true"
    else
        fail "Timer missing Persistent=true"
        FAILED=1
    fi
    
    if grep -q "WantedBy=timers.target" /etc/systemd/system/persistent-timer.timer; then
        pass "Timer has WantedBy=timers.target"
    else
        fail "Timer missing WantedBy=timers.target"
        FAILED=1
    fi
else
    fail "persistent-timer.timer not found"
    FAILED=1
fi

echo ""

echo "Checking persistent-task.sh script..."
if [ -x /usr/local/bin/persistent-task.sh ]; then
    pass "/usr/local/bin/persistent-task.sh exists and is executable"
else
    fail "/usr/local/bin/persistent-task.sh missing or not executable"
    FAILED=1
fi

echo ""

# Check if timer is enabled and running
echo "Checking persistent-timer status..."
if sudo systemctl is-enabled persistent-timer.timer &>/dev/null; then
    pass "persistent-timer.timer is enabled"
else
    fail "persistent-timer.timer is not enabled"
    FAILED=1
fi

if sudo systemctl is-active persistent-timer.timer &>/dev/null; then
    pass "persistent-timer.timer is running"
else
    fail "persistent-timer.timer is not running"
    FAILED=1
fi

echo ""

# ==================================================
# METHOD 3: COMPLEX CRON WITH ENVIRONMENT VARIABLES
# ==================================================
echo "METHOD 3: COMPLEX CRON WITH ENVIRONMENT VARIABLES"
echo "=================================================="
echo ""

echo "Checking cron configuration with environment variables..."
if sudo crontab -l 2>/dev/null | grep -q "SHELL="; then
    pass "Custom SHELL environment variable found in crontab"
else
    fail "Custom SHELL environment variable not found in crontab"
    FAILED=1
fi

if sudo crontab -l 2>/dev/null | grep -q "PATH="; then
    pass "Custom PATH environment variable found in crontab"
else
    fail "Custom PATH environment variable not found in crontab"
    FAILED=1
fi

if sudo crontab -l 2>/dev/null | grep -q "LOGFILE="; then
    pass "Custom LOGFILE environment variable found in crontab"
else
    fail "Custom LOGFILE environment variable not found in crontab"
    FAILED=1
fi

if sudo crontab -l 2>/dev/null | grep -q "env-task\|env_task\|\$LOGFILE"; then
    pass "Cron job using environment variables found"
else
    fail "Cron job using environment variables not found"
    FAILED=1
fi

echo ""

echo "Checking env-task.sh script..."
if [ -x /usr/local/bin/env-task.sh ]; then
    pass "/usr/local/bin/env-task.sh exists and is executable"
else
    fail "/usr/local/bin/env-task.sh missing or not executable"
    FAILED=1
fi

echo ""

if [ $FAILED -eq 0 ]; then
    pass "Lab scheduling-03: PASSED"
    exit 0
else
    fail "Lab scheduling-03: FAILED"
    exit 1
fi
