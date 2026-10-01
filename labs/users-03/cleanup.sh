#!/bin/bash
# users-03 cleanup: removes the users, groups and directories the lab and
# its solution create. Does nothing when the lab was not started, so an
# unrelated bob or charlie on the system is never touched.
[ -e /opt/linux-labs/state/users-03 ] || exit 0
userdel -r bob >/dev/null 2>&1
userdel -r charlie >/dev/null 2>&1
groupdel devops >/dev/null 2>&1
groupdel analytics >/dev/null 2>&1
rm -rf /srv/shared /home/bob /home/charlie
rm -f /var/spool/mail/bob /var/spool/mail/charlie
rm -f /opt/linux-labs/state/users-03
exit 0
