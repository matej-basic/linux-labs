#!/bin/bash
# users-05 cleanup: removes every file in /etc/sudoers.d that setup did
# not record (50-lab, other drop-in files, visudo leftovers), the users
# webops and auditor, the group helpdesk and their sudo records.
LAB=users-05
STATE_DIR=/opt/linux-labs/state/$LAB
STATE=$STATE_DIR/state
LIST=$STATE_DIR/sudoers.d.list

rc=0

# Without the state file the lab did not start: leave the system alone
if [ ! -f "$STATE" ]; then
	rm -rf "$STATE_DIR"
	exit 0
fi

# Drop-in files created during the lab. Without the list only the file
# of the task goes.
if [ -f "$LIST" ]; then
	find /etc/sudoers.d -mindepth 1 -maxdepth 1 -print |
		while IFS= read -r p; do
			grep -qxF -- "$p" "$LIST" || rm -rf -- "$p"
		done
else
	rm -f /etc/sudoers.d/50-lab
fi

for u in webops auditor; do
	if getent passwd "$u" >/dev/null; then
		pkill -KILL -u "$u" >/dev/null 2>&1
		userdel -r -f "$u" >/dev/null 2>&1 || rc=1
	fi
	rm -rf "/run/sudo/ts/$u" "/var/db/sudo/lectured/$u"
done
if getent group helpdesk >/dev/null; then
	groupdel helpdesk >/dev/null 2>&1 || rc=1
fi

if ! visudo -c >/dev/null 2>&1; then
	echo "Error: the sudo configuration still has errors (visudo -c)." >&2
	rc=1
fi

[ "$rc" -eq 0 ] && rm -rf "$STATE_DIR"
exit "$rc"
