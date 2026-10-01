#!/bin/bash
# webserver-01 cleanup: stop and remove Apache, delete the state file.
systemctl disable --now httpd >/dev/null 2>&1 || true
if rpm -q httpd >/dev/null 2>&1; then
	dnf -y remove httpd >/dev/null 2>&1 || true
fi
rm -f /opt/linux-labs/state/webserver-01
exit 0
