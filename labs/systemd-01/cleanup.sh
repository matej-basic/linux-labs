#!/bin/bash
# systemd-01 cleanup: remove test-service.service and its enable link.
systemctl stop test-service.service >/dev/null 2>&1 || true
systemctl disable test-service.service >/dev/null 2>&1 || true
rm -f /etc/systemd/system/test-service.service \
	/etc/systemd/system/multi-user.target.wants/test-service.service
systemctl daemon-reload >/dev/null 2>&1 || true
systemctl reset-failed test-service.service >/dev/null 2>&1 || true
exit 0
