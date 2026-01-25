#!/bin/bash

# Logging Lab 01: Journalctl Basics (Beginner)

cat <<'EOF'

LAB: Logging 01 - Journalctl Basics

OBJECTIVE
Learn to view and filter systemd journal logs.

TASKS
1) Show entries from systemd-logind:
  journalctl -u systemd-logind
2) Filter by priority (errors, warnings):
  journalctl -p err
  journalctl -p warning
  journalctl -p err,warning
3) Filter last 10 minutes:
  journalctl -S '10 minutes ago'
4) Combine filters (service + priority + time):
  journalctl -u systemd-logind -p warning -S '10 minutes ago'
5) Last 20 entries, oldest first:
  journalctl -n 20 -r
6) Follow in real time:
  journalctl -f    # Ctrl+C to exit

COMMON PRIORITIES
  emerg (0), alert (1), crit (2), err (3), warning (4), notice (5), info (6), debug (7)

COMMON FLAGS
  -u UNIT     filter by unit
  -p LEVEL    filter by priority
  -S DATE     since
  -U DATE     until
  -n NUM      last N lines
  -f          follow
  -r          reverse order

NOTES
- Some queries may need sudo.
- Journal may be non-persistent unless configured.
- For persistent journal, see logging-03.

EOF
