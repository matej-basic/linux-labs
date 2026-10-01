#!/bin/bash
# Reference solution for systemd-03, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: path /opt/lab-worker.sh
# solve: path /etc/systemd/system/lab-worker.service
# solve: path /etc/systemd/system/lab-timer.service
# solve: path /etc/systemd/system/lab-timer.timer
# solve: path /var/lib/lab-worker
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Step 1 [sudo]
cat > /opt/lab-worker.sh <<'SCRIPT'
#!/bin/bash
mkdir -p /var/lib/lab-worker
echo "Worker run at $(date)" >> /var/lib/lab-worker/execution.log
SCRIPT
chmod 755 /opt/lab-worker.sh

# Step 2 [sudo]
cat > /etc/systemd/system/lab-worker.service <<'UNIT'
[Unit]
Description=Lab worker

[Service]
Type=oneshot
ExecStart=/opt/lab-worker.sh
UNIT

# Step 3 [sudo]
cat > /etc/systemd/system/lab-timer.service <<'UNIT'
[Unit]
Description=Lab timer service

[Service]
Type=oneshot
ExecStart=/opt/lab-worker.sh
UNIT

# Step 4 [sudo]
cat > /etc/systemd/system/lab-timer.timer <<'UNIT'
[Unit]
Description=Lab timer

[Timer]
OnBootSec=1min
OnUnitActiveSec=5min

[Install]
WantedBy=timers.target
UNIT

# Step 5 [sudo]
systemctl daemon-reload
systemctl enable --now lab-timer.timer

# Step 6 [sudo]
systemctl start lab-timer.service
