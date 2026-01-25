#!/bin/bash

# Reset lab state
sudo systemctl stop test-service.service 2>/dev/null || true
sudo systemctl disable test-service.service 2>/dev/null || true
sudo rm -f /etc/systemd/system/test-service.service
sudo systemctl daemon-reload 2>/dev/null || true

# Create a simple test service for students to manage
sudo tee /etc/systemd/system/test-service.service > /dev/null <<'SERVICEEOF'
[Unit]
Description=Test Service for Learning systemctl
After=network.target

[Service]
Type=simple
ExecStart=/bin/sleep 3600
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
SERVICEEOF

sudo systemctl daemon-reload 2>/dev/null || true

cat <<'EOF'
====================================================
LAB: systemd Basics
====================================================

OBJECTIVE
Learn basic systemd service management with systemctl.

REQUIREMENTS
1) Enable the test-service.service so it starts at boot

2) Start the test-service.service

3) Verify the service is running with:
   - systemctl status test-service.service

4) Check that the service is enabled:
   - systemctl is-enabled test-service.service

NOTES
- Use systemctl to manage services
- The test-service.service unit is already created
- Root access is required for enable/start/stop operations

USEFUL COMMANDS
- systemctl enable
- systemctl start
- systemctl status
- systemctl is-enabled
- systemctl is-active
- systemctl list-unit-files

Run grading when done:
  sudo labctl grade systemd-01

====================================================
EOF

