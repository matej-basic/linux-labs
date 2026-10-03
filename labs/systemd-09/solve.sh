#!/bin/bash
# Reference solution for systemd-09, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: package sysstat
# solve: path /etc/systemd/system/sysstat-collect.timer.d
# solve: path /etc/systemd/system/report-cache.timer
# solve: path /etc/systemd/system/index-builder.service
# solve: path /usr/local/libexec/report-cache
# solve: path /usr/local/libexec/index-builder
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Steps 1 to 3 [user]
run_as_student <<'STEPS'
ps -eo pid,user,ni,%cpu,rss,comm --sort=-%cpu | head -5
ps -eo pid,user,ni,%cpu,rss,comm --sort=-rss | head -5
systemctl status "$(pgrep -x report-cache)" >/dev/null || true
systemctl status "$(pgrep -x index-builder)" >/dev/null || true
systemctl list-timers --all >/dev/null
STEPS

# Step 4 [sudo]
systemctl disable --now report-cache.timer
systemctl stop report-cache.service
systemctl disable --now index-builder.service

# Step 5 [user]
run_as_student 'echo report-cache.timer > ~/culprit.txt'

# Step 6 [sudo]
rpm -q sysstat >/dev/null || dnf -y install sysstat >/dev/null

# Step 7 [sudo]
mkdir -p /etc/systemd/system/sysstat-collect.timer.d
cat > /etc/systemd/system/sysstat-collect.timer.d/override.conf <<'CONF'
[Timer]
OnCalendar=
OnCalendar=*:00/2
CONF
systemctl daemon-reload

# Step 8 [sudo]
systemctl enable --now sysstat-collect.timer
systemctl start sysstat-collect.service

# Step 9 [user]: wait for the timer to add the second sample
intervals() {
	sadf -d "/var/log/sa/sa$(date +%d)" -- -u 2>/dev/null |
		grep -v '^#' | grep -vc RESTART || true
}
for _ in $(seq 1 60); do
	if [ "$(intervals)" -ge 1 ]; then
		run_as_student 'sar >/dev/null'
		exit 0
	fi
	sleep 5
done
echo "solve: no second sysstat sample within 5 minutes" >&2
exit 1
