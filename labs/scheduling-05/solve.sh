#!/bin/bash
# Reference solution for scheduling-05, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: path /etc/cron.d/lab-backup
# solve: path /etc/cron.d/lab-cleanup
# solve: path /usr/local/sbin/lab-report
# solve: path /var/log/cronlab
# solve: path /var/spool/cron/reports
# solve: path /home/reports
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Step 1 [sudo]: crond logs the faults at its next minute, which may not
# have come yet right after setup
grep -e lab- -e reports /var/log/cron | tail -n 20 || true

# Step 2 [sudo]
ls -l /etc/cron.d
chmod 0644 /etc/cron.d/lab-backup

# Step 3 [sudo]
sed -i 's| /usr/local/sbin/lab-report| root&|' \
	/etc/cron.d/lab-cleanup
cat /etc/cron.d/lab-cleanup

# Step 4 [sudo]
crontab -u reports -l

# Step 5 [sudo]
crontab -u reports - <<'EOF2'
# Daily report for the reports team, every minute
PATH=/usr/local/sbin:/usr/bin:/bin
* * * * * lab-report $(date +\%F) >>/var/log/cronlab/daily.log 2>&1
EOF2

# Step 6 [sudo]
sleep 65
tail -n 1 /var/log/cronlab/backup.log /var/log/cronlab/cleanup.log
tail -n 1 /var/log/cronlab/daily.log
