#!/bin/bash
source /opt/linux-labs/lib/colors.sh
rc=0

sudo crontab -l 2>/dev/null | grep -q "Daily task executed" && pass "Cron entry found" || { fail "Cron entry not found"; rc=1; }
sudo crontab -l 2>/dev/null | grep -E "^0 2 \* \* \* " | grep -q "Daily task executed" && pass "Schedule is 2 AM daily" || { fail "Schedule incorrect"; rc=1; }
sudo crontab -l 2>/dev/null | grep -q "/var/log/daily-task.log" && pass "Logs to /var/log/daily-task.log" || { fail "Log path incorrect"; rc=1; }

exit $rc
