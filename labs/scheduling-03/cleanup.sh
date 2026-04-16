#!/bin/bash
# Scheduling Lab 03: Cleanup

# Anacron cleanup
TMPFILE=$(mktemp)
grep -v "anacron_lab" /etc/anacrontab > "$TMPFILE" 2>/dev/null
sudo cp "$TMPFILE" /etc/anacrontab 2>/dev/null || true
rm -f "$TMPFILE"
sudo rm -f /usr/local/bin/anacron-task.sh
sudo rm -f /var/spool/anacron/anacron_lab

# Systemd timer cleanup
sudo systemctl stop persistent-timer.timer 2>/dev/null || true
sudo systemctl disable persistent-timer.timer 2>/dev/null || true
sudo rm -f /etc/systemd/system/persistent-timer.service
sudo rm -f /etc/systemd/system/persistent-timer.timer
sudo rm -f /usr/local/bin/persistent-task.sh

# Cron cleanup
TMPFILE=$(mktemp)
sudo crontab -l 2>/dev/null | grep -vE "SHELL=|PATH=|LOGFILE=|env_task|env-task" > "$TMPFILE"
sudo crontab "$TMPFILE" 2>/dev/null || true
rm -f "$TMPFILE"
sudo rm -f /usr/local/bin/env-task.sh

# Clean up log files
sudo rm -f /var/log/env-task.log
sudo rm -f /var/log/anacron-task.log
sudo rm -f /var/log/persistent-task.log

sudo systemctl daemon-reload &>/dev/null

echo "Cleanup complete."
