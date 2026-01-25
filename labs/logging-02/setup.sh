#!/bin/bash
# Logging Lab 02: Syslog and Logrotate (Intermediate)

cat <<'EOF'
====================================================
LAB: Logging 02 - Syslog and Logrotate
====================================================

OBJECTIVE
Configure rsyslog to capture a custom app's logs and rotate them daily.

REQUIREMENTS
1) Rsyslog config at /etc/rsyslog.d/myapp.conf with two rules:
   - local0 facility logs to /var/log/myapp.log
   - logs with programname "myapp" to /var/log/myapp-program.log
2) Reload rsyslog after creating the config.
3) Create /var/log/myapp.log and /var/log/myapp-program.log with mode 644.
4) Logrotate config at /etc/logrotate.d/myapp covering both log files with the following settings:
	- rotation should be daily
	- keep 7 rotated logs
	- compress rotated logs
	- if the file is empty, do not rotate
	- if the file is missing, do not issue an error
	- create new log files with mode 644 and owner root:root
	- after the rotation, signal rsyslog to reopen log files
5) Validate logrotate syntax: logrotate -d /etc/logrotate.d/myapp

OPTIONAL TEST
- logger -p local0.info -t myapp "Facility message" && grep "Facility message" /var/log/myapp.log
- logger -t myapp "Program message" && grep "Program message" /var/log/myapp-program.log
- logrotate -f /etc/logrotate.d/myapp && ls -l /var/log/myapp.log* /var/log/myapp-program.log*

Run grading when done:
  sudo labctl grade logging-02
====================================================
EOF
