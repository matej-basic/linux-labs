#!/bin/bash
# Scheduling Lab 02: Cleanup

sudo systemctl stop lab-task.timer 2>/dev/null || true
sudo systemctl disable lab-task.timer 2>/dev/null || true
sudo rm -f /etc/systemd/system/lab-task.timer
sudo rm -f /etc/systemd/system/lab-task.service
sudo rm -f /usr/local/bin/lab-task.sh
sudo rm -f /var/log/lab-task.log
sudo systemctl daemon-reload

echo "Cleanup complete."
