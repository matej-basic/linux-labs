#!/bin/bash
# Scheduling Lab 03: Advanced Scheduling Methods (Advanced)

cat <<'EOF'
====================================================
LAB: Scheduling 03 - Anacron and Systemd Timers
====================================================

OBJECTIVE
Configure anacron, persistent systemd timer, and complex cron jobs.

REQUIREMENTS

PART 1: Anacron
1) Create /usr/local/bin/anacron-task.sh script
   - Should log to /var/log/anacron-task.log with timestamp

2) Add anacron job to /etc/anacrontab
   - Period: 1 (daily)
   - Delay: 5 (minutes)
   - Job ID: anacron_lab
   - Command: /usr/local/bin/anacron-task.sh

PART 2: Systemd Persistent Timer
1) Create /etc/systemd/system/persistent-timer.service
   - Type: oneshot
   - ExecStart: /usr/local/bin/persistent-task.sh

2) Create /etc/systemd/system/persistent-timer.timer
   - OnBootSec: 30s
   - OnUnitActiveSec: 1h
   - Persistent: true (catch up on missed runs)
   - Install in timers.target

3) Create /usr/local/bin/persistent-task.sh script
   - Should log to /var/log/persistent-task.log with timestamp
   - Must be executable

4) Enable and start the timer

PART 3: Complex Cron with Environment Variables
1) Create /usr/local/bin/env-task.sh script
   - Should log to /var/log/env-task.log with timestamp

2) Add to root crontab with environment variables:
   - SHELL=/bin/bash
   - PATH (standard system path)
   - LOGFILE=/var/log/env-task.log

3) Schedule the job every 6 hours

USEFUL COMMANDS
- sudo systemctl status anacron
- sudo systemctl list-timers
- sudo crontab -e
- sudo systemctl daemon-reload
- man anacrontab
- man systemd.timer

Run grading when done:
  sudo labctl grade scheduling-03
====================================================
EOF
