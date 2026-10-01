#!/bin/bash
# systemd-01 setup: install test-service.service, disabled and stopped.
# Prints nothing on success.
set -eu

UNIT=/etc/systemd/system/test-service.service

# Reset lab state
systemctl stop test-service.service >/dev/null 2>&1 || true
systemctl disable test-service.service >/dev/null 2>&1 || true
rm -f "$UNIT" /etc/systemd/system/multi-user.target.wants/test-service.service

cat > "$UNIT" <<'UNITEOF'
[Unit]
Description=Test service for learning systemctl
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/sleep 3600
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
UNITEOF
chmod 644 "$UNIT"
restorecon "$UNIT" >/dev/null 2>&1 || true

systemctl daemon-reload
systemctl reset-failed test-service.service >/dev/null 2>&1 || true
