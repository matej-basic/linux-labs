#!/bin/bash
# systemd-02 cleanup: remove the service, script and log the lab and its
# solution create.
systemctl stop custom-app.service >/dev/null 2>&1 || true
systemctl disable custom-app.service >/dev/null 2>&1 || true
rm -rf /etc/systemd/system/custom-app.service \
	/etc/systemd/system/custom-app.service.d \
	/etc/systemd/system/multi-user.target.wants/custom-app.service \
	/opt/custom-app.sh /var/log/custom-app.log \
	/opt/linux-labs/state/systemd-02
systemctl daemon-reload >/dev/null 2>&1 || true
systemctl reset-failed custom-app.service >/dev/null 2>&1 || true
exit 0
