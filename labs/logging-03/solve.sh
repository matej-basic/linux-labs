#!/bin/bash
# Reference solution for logging-03, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# The lab's /var/log/journal is not declared: reset restores a journal
# that existed before the lab, so the path may legitimately remain.
# solve: path /var/log/journal.labctl-backup
# solve: path /etc/systemd/system/labtest-fail.service
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Step 1 [sudo]
mkdir -p /var/log/journal
chmod 755 /var/log/journal
systemctl restart systemd-journald
journalctl --flush

# Step 2 [sudo]
cat > /etc/systemd/system/labtest-fail.service <<'UNIT'
[Unit]
Description=Lab Test Fail Service

[Service]
Type=simple
ExecStart=/bin/false

[Install]
WantedBy=multi-user.target
UNIT

# Step 3 [sudo]
systemctl daemon-reload
systemctl start labtest-fail.service || true
sleep 1

# Step 4 [sudo], practice commands
journalctl --list-boots >/dev/null
journalctl -u labtest-fail.service -p err >/dev/null || true
systemd-analyze time >/dev/null
