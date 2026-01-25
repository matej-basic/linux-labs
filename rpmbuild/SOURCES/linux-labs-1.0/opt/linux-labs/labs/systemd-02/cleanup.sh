#!/bin/bash

echo "Cleanup: systemd-02"

sudo systemctl stop custom-app.service >/dev/null 2>&1 || true
sudo systemctl disable custom-app.service >/dev/null 2>&1 || true
sudo rm -f /etc/systemd/system/custom-app.service /opt/custom-app.sh
sudo rm -f /var/log/custom-app.log
sudo systemctl daemon-reload >/dev/null 2>&1 || true

echo "Cleanup completed."
