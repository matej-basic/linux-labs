#!/bin/bash
# users-06 cleanup: removes anna, ben, carla and dario with their home
# directories, mail spools and faillock records, and the state.
LAB=users-06
STATE_DIR=/opt/linux-labs/state/$LAB
USERS="anna ben carla dario"

# Without the state the lab did not create the users: leave them alone
[ -d "$STATE_DIR" ] || exit 0

rc=0
for u in $USERS; do
	if getent passwd "$u" >/dev/null; then
		pkill -KILL -u "$u" >/dev/null 2>&1
		faillock --user "$u" --reset >/dev/null 2>&1
		userdel -r -f "$u" >/dev/null 2>&1
	fi
	if getent passwd "$u" >/dev/null; then
		echo "Error: cannot remove user $u." >&2
		rc=1
		continue
	fi
	if getent group "$u" >/dev/null; then
		groupdel "$u" >/dev/null 2>&1 || rc=1
	fi
	rm -rf "/home/${u:?}"
	rm -f "/var/spool/mail/$u" "/var/run/faillock/$u"
done

# Keep the state when something failed, so that a second reset tries
# again
[ "$rc" -eq 0 ] && rm -rf "$STATE_DIR"
exit "$rc"
