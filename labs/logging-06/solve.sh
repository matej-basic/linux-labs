#!/bin/bash
# Reference solution for logging-06, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# /var/log/journal and the drop-in directory are not declared: the reset
# restores them when they existed before the lab, so the paths may
# legitimately remain.
# solve: path /etc/systemd/journald.conf.d/50-limits.conf
# solve: path /var/log/journal.logging-06-backup
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Step 1 [sudo]
mkdir -p /etc/systemd/journald.conf.d
cat > /etc/systemd/journald.conf.d/50-limits.conf <<'CONF'
[Journal]
Storage=persistent
SystemMaxUse=100M
SystemMaxFileSize=20M
RateLimitIntervalSec=10s
RateLimitBurst=500
MaxRetentionSec=2week
CONF
systemd-analyze cat-config systemd/journald.conf >/dev/null

# Step 2 [sudo]
systemctl restart systemd-journald
journalctl --flush
journalctl --disk-usage >/dev/null

# Step 3 [sudo]
systemctl restart rsyslog

# Step 4 [user]
run_as_student 'logger -t labjournal "journald limits applied"'
sleep 3

# Step 5 [sudo]
journalctl -t labjournal -n 1 >/dev/null
grep labjournal /var/log/messages >/dev/null
