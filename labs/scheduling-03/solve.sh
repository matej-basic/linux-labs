#!/bin/bash
# Reference solution for scheduling-03, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: path /usr/local/bin/anacron-task.sh
# solve: path /usr/local/bin/persistent-task.sh
# solve: path /usr/local/bin/env-task.sh
# solve: path /etc/systemd/system/persistent-timer.service
# solve: path /etc/systemd/system/persistent-timer.timer
# solve: path /var/log/anacron-task.log
# solve: path /var/log/persistent-task.log
# solve: path /var/log/env-task.log
# solve: path /var/spool/anacron/anacron_lab
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Steps 1 to 2 [sudo]
cat > /usr/local/bin/anacron-task.sh <<'EOF2'
#!/bin/bash
echo "Anacron task ran at $(date)" >> /var/log/anacron-task.log
EOF2
chmod +x /usr/local/bin/anacron-task.sh
echo '1 5 anacron_lab /usr/local/bin/anacron-task.sh' >> /etc/anacrontab
anacron -T

# Steps 3 to 6 [sudo]
cat > /usr/local/bin/persistent-task.sh <<'EOF2'
#!/bin/bash
echo "Persistent task ran at $(date)" >> /var/log/persistent-task.log
EOF2
chmod +x /usr/local/bin/persistent-task.sh
cat > /etc/systemd/system/persistent-timer.service <<'EOF2'
[Unit]
Description=Persistent timer service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/persistent-task.sh
EOF2
cat > /etc/systemd/system/persistent-timer.timer <<'EOF2'
[Unit]
Description=Persistent timer

[Timer]
OnBootSec=30s
OnUnitActiveSec=1h
Persistent=true

[Install]
WantedBy=timers.target
EOF2
systemctl daemon-reload
systemctl enable --now persistent-timer.timer

# Steps 7 to 8 [sudo]
cat > /usr/local/bin/env-task.sh <<'EOF2'
#!/bin/bash
echo "env_task ran at $(date)" >> "${LOGFILE:-/var/log/env-task.log}"
EOF2
chmod +x /usr/local/bin/env-task.sh
{
	crontab -l 2>/dev/null || true
	cat <<'EOF2'
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
LOGFILE=/var/log/env-task.log
0 */6 * * * /usr/local/bin/env-task.sh
EOF2
} | crontab -
