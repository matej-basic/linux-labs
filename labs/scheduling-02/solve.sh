#!/bin/bash
# Reference solution for scheduling-02, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: path /usr/local/bin/lab-task.sh
# solve: path /etc/systemd/system/lab-task.service
# solve: path /etc/systemd/system/lab-task.timer
# solve: path /etc/systemd/system/timers.target.wants/lab-task.timer
# solve: path /var/log/lab-task.log
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Step 1 [sudo]
tee /usr/local/bin/lab-task.sh > /dev/null <<'EOF2'
#!/bin/bash
echo "Lab task executed at $(date)" >> /var/log/lab-task.log
EOF2
chmod +x /usr/local/bin/lab-task.sh

# Step 2 [sudo]
tee /etc/systemd/system/lab-task.service > /dev/null <<'EOF2'
[Unit]
Description=Lab task service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/lab-task.sh
EOF2

# Step 3 [sudo]
tee /etc/systemd/system/lab-task.timer > /dev/null <<'EOF2'
[Unit]
Description=Lab task timer

[Timer]
OnBootSec=1min
OnUnitActiveSec=10min

[Install]
WantedBy=timers.target
EOF2

# Step 4 [sudo]
systemctl daemon-reload
systemctl enable --now lab-task.timer
