#!/bin/bash
# Scheduling Lab 01: Cron Jobs Basics (Beginner)

cat <<'EOF'
====================================================
LAB: Scheduling 01 - Cron Jobs Basics
====================================================

OBJECTIVE
Create a cron job for the root user that runs daily at 2 AM.

REQUIREMENTS
1) Create a cron job that executes every day at 2:00 AM.
2) The job should print 'Daily task executed' to /var/log/daily-task.log.

USEFUL COMMANDS
- sudo crontab -e        Edit cron table
- sudo crontab -l        List cron entries
- sudo crontab -r        Remove all entries
- cat /etc/crontab       View system-wide cron file

Run grading when done:
  sudo labctl grade scheduling-01
====================================================
EOF
