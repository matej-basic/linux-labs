#!/bin/bash
# files-03 cleanup: removes the tree, the archive, alice and developers.
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
exit 0
