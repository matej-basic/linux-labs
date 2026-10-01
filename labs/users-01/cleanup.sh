#!/bin/bash
# users-01 cleanup: remove the users, group and directories created by
# the lab or its solution.
for u in alice svcapp; do
	if getent passwd "$u" >/dev/null; then
		userdel -r "$u" >/dev/null 2>&1 || userdel -f "$u" >/dev/null 2>&1 || true
	fi
done
if getent group project >/dev/null; then
	groupdel project >/dev/null 2>&1 || true
fi
rm -rf /home/alice /srv/project /srv/svcapp
rm -f /var/spool/mail/alice /var/spool/mail/svcapp
exit 0
