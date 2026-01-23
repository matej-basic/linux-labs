#!/bin/bash
# Scheduling Lab 01: Cleanup

TMPFILE=$(mktemp)
sudo crontab -l 2>/dev/null | grep -v "Daily task executed" | sudo crontab - 2>/dev/null || true
rm -f "$TMPFILE"
sudo rm -f /var/log/daily-task.log || true

echo "Cleanup complete."
