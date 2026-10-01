#!/bin/bash
# Reference solution for systemd-02, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: path /opt/custom-app.sh
# solve: path /etc/systemd/system/custom-app.service
# solve: path /var/log/custom-app.log
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Step 1 [sudo]
cat > /opt/custom-app.sh <<'SCRIPT'
#!/bin/bash
while true; do
    echo "Custom app running at $(date)" >> /var/log/custom-app.log
    sleep 5
done
SCRIPT
chmod +x /opt/custom-app.sh

# Step 2 [sudo]
cat > /etc/systemd/system/custom-app.service <<'SERVICE'
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

# Step 3 [sudo]
systemctl daemon-reload
systemctl enable custom-app.service
systemctl start custom-app.service
sleep 1
