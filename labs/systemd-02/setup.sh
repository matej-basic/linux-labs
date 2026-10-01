#!/bin/bash
# systemd-02 setup: remove any custom-app service left from an earlier
# run, so the lab starts without script, unit or log. Prints nothing.
set -eu

systemctl stop custom-app.service >/dev/null 2>&1 || true
systemctl disable custom-app.service >/dev/null 2>&1 || true
rm -rf /etc/systemd/system/custom-app.service \
	/etc/systemd/system/custom-app.service.d \
	/etc/systemd/system/multi-user.target.wants/custom-app.service \
	/opt/custom-app.sh /var/log/custom-app.log
systemctl daemon-reload
systemctl reset-failed custom-app.service >/dev/null 2>&1 || true
exit 0
