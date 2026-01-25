# Solution: systemd-02 (custom service creation)

```bash
# 1) Create the executable script at /opt/custom-app.sh
sudo tee /opt/custom-app.sh >/dev/null <<'SCRIPT'
#!/bin/bash
while true; do
    echo "Custom app running at $(date)" >> /var/log/custom-app.log
    sleep 5
done
SCRIPT
sudo chmod +x /opt/custom-app.sh

# 2) Create the service unit file
sudo tee /etc/systemd/system/custom-app.service >/dev/null <<'SERVICE'
[Unit]
Description=Custom Application Service
After=network.target

[Service]
Type=simple
ExecStart=/opt/custom-app.sh
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
SERVICE

# 3) Reload systemd, enable, and start
sudo systemctl daemon-reload
sudo systemctl enable custom-app.service
sudo systemctl start custom-app.service

# 4) Verify
sudo systemctl status custom-app.service
sudo systemctl is-enabled custom-app.service
tail /var/log/custom-app.log

# 5) Grade
sudo labctl grade systemd-02
```
