#!/bin/bash
# files-03 setup: removes leftovers of an earlier run, so the student
# starts without /srv/secure, the backup, alice and the developers group.
# Prints nothing on success.
set -eu
source /opt/linux-labs/lib/packages.sh
pkg_snapshot files-03

# Reset lab state (the user first, because developers may be her group)
rm -rf /srv/secure /tmp/backup.tar.gz
if getent passwd alice >/dev/null; then
	userdel -rf alice >/dev/null 2>&1 || true
fi
if getent group alice >/dev/null; then
	groupdel alice >/dev/null 2>&1 || true
fi
if getent group developers >/dev/null; then
	groupdel developers
fi

# The lab asks for fixed IDs; refuse if something else already uses them
if getent passwd 1001 >/dev/null; then
	echo "files-03: UID 1001 is already used by $(getent passwd 1001 | cut -d: -f1); the lab needs it for alice." >&2
	exit 1
fi
if getent group 3000 >/dev/null; then
	echo "files-03: GID 3000 is already used by $(getent group 3000 | cut -d: -f1); the lab needs it for developers." >&2
	exit 1
fi

# setfacl and getfacl come from the acl package
if ! command -v setfacl >/dev/null 2>&1; then
	if ! dnf -y -q install acl >/dev/null 2>&1; then
		echo "files-03: the acl package is missing and could not be installed." >&2
		exit 1
	fi
fi
