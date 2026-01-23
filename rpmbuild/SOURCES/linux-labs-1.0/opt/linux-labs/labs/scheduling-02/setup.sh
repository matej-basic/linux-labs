#!/bin/bash
# Scheduling Lab 02: Systemd Timers (Intermediate)

cat <<'EOF'
====================================================
LAB: Scheduling 02 - Systemd Timers
====================================================

OBJECTIVE
Create a systemd timer that runs a task every 10 minutes.

REQUIREMENTS
1) Create a systemd service file at /etc/systemd/system/lab-task.service
   - Type should be "oneshot"
   - ExecStart should point to /usr/local/bin/lab-task.sh

2) Create a systemd timer file at /etc/systemd/system/lab-task.timer
   - OnBootSec should be 1min
   - OnUnitActiveSec should be 10min
   - Must be installed in timers.target

3) Create /usr/local/bin/lab-task.sh script
   - Should append to /var/log/lab-task.log with timestamp
   - Must be executable

4) Enable and start the timer using systemctl

5) Verify with: sudo systemctl list-timers lab-task.timer

USEFUL COMMANDS
- man systemd.service
- man systemd.timer
- sudo systemctl daemon-reload
- sudo systemctl enable
- sudo systemctl start
- sudo systemctl list-timers

Run grading when done:
  sudo labctl grade scheduling-02
====================================================
EOF
