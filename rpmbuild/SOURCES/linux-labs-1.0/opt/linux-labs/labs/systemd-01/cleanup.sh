#!/bin/bash

echo "Cleanup: systemd-01"

sudo systemctl stop test-service.service >/dev/null 2>&1 || true
sudo systemctl disable test-service.service >/dev/null 2>&1 || true
sudo rm -f /etc/systemd/system/test-service.service
sudo systemctl daemon-reload >/dev/null 2>&1 || true

echo "Cleanup completed."
