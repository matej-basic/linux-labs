#!/bin/bash
# Reference solution for logging-02, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: path /etc/rsyslog.d/myapp.conf
# solve: path /etc/logrotate.d/myapp
# solve: path /var/log/myapp.log
# solve: path /var/log/myapp-program.log
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Step 1 [sudo]
cat >/etc/rsyslog.d/myapp.conf <<'EOT'
local0.*                            /var/log/myapp.log
:programname, isequal, "myapp"      /var/log/myapp-program.log
EOT

# Step 2 [sudo]
touch /var/log/myapp.log /var/log/myapp-program.log
chmod 644 /var/log/myapp.log /var/log/myapp-program.log

# Step 3 [sudo]
systemctl restart rsyslog

# Step 4 [sudo]
cat >/etc/logrotate.d/myapp <<'EOT'
/var/log/myapp.log /var/log/myapp-program.log {
    daily
    rotate 7
    compress
    missingok
    notifempty
    create 644 root root
    postrotate
        systemctl kill -s HUP rsyslog >/dev/null 2>&1 || true
    endscript
}
EOT
logrotate -d /etc/logrotate.d/myapp

# Step 5 [user]
run_as_student <<'STEPS'
logger -p local0.info -t other "Facility message"
logger -t myapp "Program message"
sleep 2
grep "Facility message" /var/log/myapp.log
grep "Program message" /var/log/myapp-program.log
STEPS
