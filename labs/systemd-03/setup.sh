#!/bin/bash

# Reset lab state
sudo systemctl stop lab-worker.service 2>/dev/null || true
sudo systemctl stop lab-timer.timer 2>/dev/null || true
sudo systemctl disable lab-worker.service 2>/dev/null || true
sudo systemctl disable lab-timer.timer 2>/dev/null || true
sudo systemctl set-default multi-user.target 2>/dev/null || true
sudo rm -f /etc/systemd/system/lab-worker.service
sudo rm -f /etc/systemd/system/lab-timer.timer
sudo rm -f /etc/systemd/system/lab-timer.service
sudo rm -f /opt/lab-worker.sh
sudo rm -rf /var/lib/lab-worker
mkdir -p /var/lib
sudo systemctl daemon-reload 2>/dev/null || true

cat <<'EOF'
====================================================
LAB: systemd Timers and Advanced Services
====================================================

OBJECTIVE
Create a worker application with systemd timers for scheduled execution.

REQUIREMENTS
1) Create /opt/lab-worker.sh script
   - Should log execution to /var/lib/lab-worker/execution.log
   - Include a timestamp with each execution

2) Create /etc/systemd/system/lab-worker.service
   - Type: oneshot
   - ExecStart: /opt/lab-worker.sh
   - Should be executable by systemd

3) Create /etc/systemd/system/lab-timer.timer
   - OnBootSec: 1 minute
   - OnUnitActiveSec: 5 minutes
   - Install in timers.target

4) Create /etc/systemd/system/lab-timer.service
   - Type: oneshot
   - ExecStart: /opt/lab-worker.sh

5) Enable and start the timer
   - Make it persistent at boot
   - Start immediately

6) Verify timer execution
   - Check log file for entries
   - Verify timer is active

USEFUL COMMANDS
- mkdir -p (create directories)
- sudo systemctl daemon-reload
- sudo systemctl enable
- sudo systemctl start
- sudo systemctl list-timers
- sudo systemctl status
- sudo journalctl -u lab-timer.timer
- tail -f /var/lib/lab-worker/execution.log

Run grading when done:
  sudo labctl grade systemd-03

====================================================
EOF

