#!/bin/bash
# Remove the tree and, only if setup.sh created it, the apache user.
rm -rf /tmp/webfiles

if grep -qx 'apache_created=yes' /opt/linux-labs/state/files-02 2>/dev/null &&
	! rpm -q httpd >/dev/null 2>&1; then
	userdel apache 2>/dev/null || true
	getent group apache >/dev/null && groupdel apache 2>/dev/null || true
fi

rm -f /opt/linux-labs/state/files-02
exit 0
