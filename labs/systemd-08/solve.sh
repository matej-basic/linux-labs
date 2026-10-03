#!/bin/bash
# Reference solution for systemd-08, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: path /etc/systemd/system/labapp.service.d
# solve: path /usr/lib/systemd/system/labapp.service
# solve: path /usr/local/libexec/labapp
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Step 1 [sudo]
mkdir -p /etc/systemd/system/labapp.service.d
cat > /etc/systemd/system/labapp.service.d/override.conf <<'CONF'
[Service]
Restart=on-failure
RestartSec=5
Environment=LAB_MODE=production
MemoryMax=128M
CPUQuota=50%
CONF
systemctl daemon-reload

# Step 2 [sudo]
systemctl enable labapp.service
systemctl restart labapp.service
sleep 1
