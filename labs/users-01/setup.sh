#!/bin/bash
# users-01 setup: remove the users, group and directories the lab
# creates, so every start begins from the same state. Prints nothing.
set -eu

for u in alice svcapp; do
	if getent passwd "$u" >/dev/null; then
		userdel -r "$u" >/dev/null 2>&1 || userdel -f "$u" >/dev/null 2>&1 || true
	fi
done
if getent group project >/dev/null; then
	groupdel project >/dev/null 2>&1 || true
fi
rm -rf /home/alice /srv/project /srv/svcapp

# Refuse to start if the old accounts could not be removed
if getent passwd alice >/dev/null || getent passwd svcapp >/dev/null \
	|| getent group project >/dev/null; then
	echo "users-01: could not remove the existing alice, svcapp or project" >&2
	exit 1
fi
