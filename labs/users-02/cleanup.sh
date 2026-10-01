#!/bin/bash
# users-02 cleanup: removes dave, eve, the group, the limits file and
# restores the login.defs aging values recorded by setup.
STATE_FILE=/opt/linux-labs/state/users-02

# Without the state file the lab did not start: leave existing accounts alone
if [ -f "$STATE_FILE" ]; then
	for u in dave eve; do
		if getent passwd "$u" >/dev/null; then
			userdel -r -f "$u" >/dev/null 2>&1
		fi
	done
	groupdel contractors >/dev/null 2>&1
	rm -f /etc/security/limits.d/70-contractors.conf

	for k in PASS_MAX_DAYS PASS_MIN_DAYS PASS_WARN_AGE; do
		val=$(sed -n "s/^$k=//p" "$STATE_FILE")
		sed -i -E "/^[[:space:]]*${k}[[:space:]]/d" /etc/login.defs
		if [ -n "$val" ]; then
			printf '%s\t%s\n' "$k" "$val" >> /etc/login.defs
		fi
	done
fi

rm -f "$STATE_FILE"
exit 0
