#!/bin/bash

echo "Cleanup: systemd-03"

sudo systemctl stop lab-worker.service >/dev/null 2>&1 || true
sudo systemctl stop lab-timer.timer >/dev/null 2>&1 || true
sudo systemctl disable lab-worker.service >/dev/null 2>&1 || true
sudo systemctl disable lab-timer.timer >/dev/null 2>&1 || true
sudo systemctl set-default multi-user.target >/dev/null 2>&1 || true
sudo rm -f /etc/systemd/system/lab-worker.service
sudo rm -f /etc/systemd/system/lab-timer.timer
sudo rm -f /etc/systemd/system/lab-timer.service
sudo rm -f /opt/lab-worker.sh
sudo rm -rf /var/lib/lab-worker
sudo systemctl daemon-reload >/dev/null 2>&1 || true

echo "Cleanup completed."
