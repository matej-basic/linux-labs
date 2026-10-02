#!/bin/bash
# users-03 cleanup: removes the users, groups and directories the lab and
# its solution create, then restores the package set (acl, when the lab
# had to install it). The accounts are removed only when the lab was
# started, so an unrelated bob or charlie is never touched.
source /opt/linux-labs/lib/packages.sh
if [ -e /opt/linux-labs/state/users-03 ]; then
	userdel -r bob >/dev/null 2>&1
	userdel -r charlie >/dev/null 2>&1
	groupdel devops >/dev/null 2>&1
	groupdel analytics >/dev/null 2>&1
	rm -rf /srv/shared /home/bob /home/charlie
	rm -f /var/spool/mail/bob /var/spool/mail/charlie
	rm -f /opt/linux-labs/state/users-03
fi
rc=0
pkg_restore users-03 || rc=1
exit "$rc"
