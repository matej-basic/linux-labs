#!/bin/bash
# files-09 cleanup: removes the tree, the answer file and the state file.
# Works when the lab was never started.
STATE_FILE=/opt/linux-labs/state/files-09

dir=""
[ -r "$STATE_FILE" ] && dir=$(sed -n 's/^answers=//p' "$STATE_FILE")
if [ -z "$dir" ]; then
	home=$(getent passwd "${LAB_USER:-student}" | cut -d: -f6)
	[ -n "$home" ] && dir="$home/answers"
fi
if [ -n "$dir" ] && [ -d "$dir" ]; then
	rm -f "$dir/inode-names.txt"
	rmdir "$dir" 2>/dev/null || true
fi

rm -rf /srv/linklab
rm -f "$STATE_FILE"
exit 0
