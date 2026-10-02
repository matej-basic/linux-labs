#!/bin/bash
# files-03 cleanup: removes the tree, the archive, alice and developers,
# then restores the package set of the first start (acl goes again if
# setup installed it).
source /opt/linux-labs/lib/packages.sh

rm -rf /srv/secure /tmp/backup.tar.gz
if getent passwd alice >/dev/null; then
	userdel -rf alice >/dev/null 2>&1 || true
fi
if getent group alice >/dev/null; then
	groupdel alice >/dev/null 2>&1 || true
fi
if getent group developers >/dev/null; then
	groupdel developers >/dev/null 2>&1 || true
fi
rc=0
pkg_restore files-03 || rc=1
exit "$rc"
