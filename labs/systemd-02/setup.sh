#!/bin/bash

# Reset lab state
sudo systemctl stop custom-app.service 2>/dev/null || true
sudo systemctl disable custom-app.service 2>/dev/null || true
sudo rm -f /etc/systemd/system/custom-app.service /opt/custom-app.sh
mkdir -p /opt
sudo systemctl daemon-reload 2>/dev/null || true

cat <<'EOF'
====================================================
LAB: systemd Service Creation and Debugging
====================================================

OBJECTIVE
Create a custom systemd service, fix issues, and manage the service lifecycle.

REQUIREMENTS
1) Create /opt/custom-app.sh script
   - Should run indefinitely (use loop or sleep)
   - Should log output to /var/log/custom-app.log

2) Create a systemd service file
   - Path: /etc/systemd/system/custom-app.service
   - Type: simple (runs in foreground)
   - ExecStart: /opt/custom-app.sh

3) Enable and start the service
   - Make it persistent (enable at boot)
   - Start the service immediately

4) Verify the service is running
   - Check status with systemctl
   - Check the log file

5) Reload and restart the service
   - After modifying the service file

USEFUL COMMANDS
- sudo systemctl daemon-reload
- sudo systemctl enable
- sudo systemctl start
- sudo systemctl status
- sudo systemctl restart
- sudo journalctl -u custom-app.service
- sudo tail -f /var/log/custom-app.log

Run grading when done:
  sudo labctl grade systemd-02

====================================================
EOF

