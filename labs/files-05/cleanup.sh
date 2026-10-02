#!/bin/bash
# files-05 cleanup: removes the data tree, the answer files, the lab users
# and the state file. Works when the lab was never started.
LAB=files-05
STATE_FILE=/opt/linux-labs/state/$LAB
MARK="linux-labs $LAB"
ANSWERS="large-files.txt old-files.txt setuid.txt link-count.txt
errors.txt report-files.txt denied.txt"

# Answers directory: from the state file, else in the home of LAB_USER
dir=""
[ -r "$STATE_FILE" ] && dir=$(sed -n 2p "$STATE_FILE")
if [ -z "$dir" ]; then
	home=$(getent passwd "${LAB_USER:-student}" | cut -d: -f6)
	[ -n "$home" ] && dir="$home/answers"
fi
if [ -n "$dir" ] && [ -d "$dir" ]; then
	for a in $ANSWERS; do
		rm -f "$dir/$a"
	done
	rmdir "$dir" 2>/dev/null || true
fi

rm -rf /srv/search

# Only the accounts this lab created
for u in analyst builder tester; do
	if [ "$(getent passwd "$u" | cut -d: -f5)" = "$MARK" ]; then
		userdel -r -f "$u" >/dev/null 2>&1 || true
	fi
done

rm -f "$STATE_FILE"
exit 0
