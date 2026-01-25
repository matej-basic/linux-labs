# Solution: systemd-03 (timers and scheduled tasks)

```bash
# 1) Create the worker script
sudo mkdir -p /var/lib/lab-worker
sudo tee /opt/lab-worker.sh >/dev/null <<'SCRIPT'
#!/bin/bash
mkdir -p /var/lib/lab-worker
echo "Worker executed at $(date)" >> /var/lib/lab-worker/execution.log
SCRIPT
sudo chmod +x /opt/lab-worker.sh

# 2) Create lab-timer.service (triggered by timer)
sudo tee /etc/systemd/system/lab-timer.service >/dev/null <<'SERVICE'
[Unit]
Description=Lab Timer Service
After=network.target

[Service]
Type=oneshot
ExecStart=/opt/lab-worker.sh
SERVICE

# 3) Create lab-timer.timer
sudo tee /etc/systemd/system/lab-timer.timer >/dev/null <<'TIMER'
[Unit]
Description=Lab Timer

[Timer]
OnBootSec=1min
OnUnitActiveSec=5min

[Install]
WantedBy=timers.target
TIMER

# 4) Create lab-worker.service (alternative/legacy)
sudo tee /etc/systemd/system/lab-worker.service >/dev/null <<'SERVICE2'
[Unit]
Description=Lab Worker Service
After=network.target

[Service]
Type=oneshot
ExecStart=/opt/lab-worker.sh
SERVICE2

# 5) Reload, enable, start
sudo systemctl daemon-reload
sudo systemctl enable lab-timer.timer
sudo systemctl start lab-timer.timer

# 6) Verify
sudo systemctl status lab-timer.timer
sudo systemctl list-timers lab-timer.timer
tail /var/lib/lab-worker/execution.log

# 7) Grade
sudo labctl grade systemd-03
```
