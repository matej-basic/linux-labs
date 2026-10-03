#!/bin/bash
# files-08 cleanup: removes the data files, the reports directory and the
# state file. Works when the lab was never started.
LAB=files-08
STATE_FILE=/opt/linux-labs/state/$LAB

# Reports directory: from the state file, else in the home of LAB_USER
dir=""
[ -r "$STATE_FILE" ] && dir=$(sed -n 2p "$STATE_FILE")
if [ -z "$dir" ]; then
	home=$(getent passwd "${LAB_USER:-student}" | cut -d: -f6)
	[ -n "$home" ] && dir="$home/reports"
fi
case $dir in
*/reports) rm -rf "$dir" ;;
esac

rm -rf /srv/textlab
rm -f "$STATE_FILE"
exit 0
