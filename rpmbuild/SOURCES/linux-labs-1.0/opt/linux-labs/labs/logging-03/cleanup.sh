#!/bin/bash
# Logging Lab 03: Cleanup

systemctl stop labtest-fail.service 2>/dev/null || true
rm -f /etc/systemd/system/labtest-fail.service
systemctl daemon-reload

echo "Cleanup complete. Persistent journal remains in /var/log/journal."
