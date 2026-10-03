#!/bin/bash
# Reference solution for systemd-10, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: path /etc/systemd/system/reportd.service
# solve: path /etc/systemd/system/inventoryd.service
# solve: path /etc/systemd/system/metricsd.service
# solve: path /etc/systemd/system/multi-user.target.wants/metricsd.service
# solve: path /usr/local/bin/reportd
# solve: path /usr/local/bin/inventoryd
# solve: path /usr/local/bin/metricsd
# solve: path /etc/sysconfig/inventoryd
# solve: path /etc/sysconfig/inventoryd.example
# solve: path /var/lib/inventoryd
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Step 1 [user]
run_as_student <<'STEPS'
systemctl status reportd inventoryd metricsd >/dev/null || true
journalctl -u reportd -u inventoryd -u metricsd --no-pager >/dev/null || true
STEPS

# Step 2 [sudo]
chmod 755 /usr/local/bin/reportd
restorecon -v /usr/local/bin/reportd >/dev/null

# Step 3 [sudo]
cp /etc/sysconfig/inventoryd.example /etc/sysconfig/inventoryd

# Step 4 [sudo]
sed -i 's/^Type=forking$/Type=simple/' /etc/systemd/system/metricsd.service
printf '\n[Install]\nWantedBy=multi-user.target\n' |
	tee -a /etc/systemd/system/metricsd.service >/dev/null
systemctl daemon-reload

# Step 5 [sudo]
systemctl enable reportd inventoryd metricsd
systemctl restart reportd inventoryd metricsd

# Step 6 [user]
run_as_student <<'STEPS'
systemctl is-active reportd inventoryd metricsd
ps -eo user,pid,args | grep /usr/local/bin/
systemd-analyze verify /etc/systemd/system/reportd.service \
	/etc/systemd/system/inventoryd.service \
	/etc/systemd/system/metricsd.service
STEPS
