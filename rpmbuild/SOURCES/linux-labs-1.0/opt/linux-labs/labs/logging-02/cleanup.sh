#!/bin/bash
# Logging Lab 02: Cleanup Script

sudo rm -f /etc/rsyslog.d/myapp.conf
sudo systemctl reload rsyslog 2>/dev/null || true
sudo rm -f /etc/logrotate.d/myapp
sudo rm -f /var/log/myapp.log*

echo "Cleanup complete."
