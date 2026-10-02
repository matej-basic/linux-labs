#!/bin/bash
# files-04 setup: an empty /srv/archive owned by the lab user, and a state
# file that records the owner for the grader. Prints nothing on success.
set -eu

STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/files-04"

# Lab owner: the task user labctl exports as LAB_USER (the user who ran
# sudo labctl start), else "student". If that user does not exist, use the
# first regular user (UID >= 1000), else root.
owner="${LAB_USER:-student}"
if ! id "$owner" &>/dev/null; then
	owner=$(getent passwd | awk -F: '$3 >= 1000 && $3 < 60000 { print $1; exit }')
	owner="${owner:-root}"
fi

# Reset lab state
rm -rf /srv/archive
mkdir -p /srv/archive
chown "$owner": /srv/archive
chmod 755 /srv/archive

# Record the owner for the grader (readable by unprivileged users)
mkdir -p "$STATE_DIR"
echo "$owner" > "$STATE_FILE"
chmod 644 "$STATE_FILE"
