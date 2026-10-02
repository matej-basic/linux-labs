#!/bin/bash
# ssh-01 setup: the local account deploy (no password, key login only)
# and a record of the task user's SSH client files that existed before
# the lab, so cleanup can put them back. Prints nothing on success.
set -eu

LAB=ssh-01
STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/$LAB"
BACKUP_DIR="$STATE_DIR/$LAB.d"
# Files in ~/.ssh of the task user that the lab or its solution may change
SAVED="config known_hosts known_hosts.old"

# Restart: undo the previous run (and its solution) first, so the record
# below describes the state from before the lab
if [ -f "$STATE_FILE" ]; then
	bash "$(dirname "$0")/cleanup.sh"
fi

# Task user: LAB_USER from labctl, else the first regular user
owner="${LAB_USER:-student}"
if ! id "$owner" &>/dev/null; then
	owner=$(getent passwd | awk -F: '$3 >= 1000 && $3 < 60000 { print $1; exit }')
fi
if [ -z "$owner" ] || ! id "$owner" &>/dev/null; then
	echo "Error: no regular user account found for the lab." >&2
	exit 1
fi
home=$(getent passwd "$owner" | cut -d: -f6)
if [ -z "$home" ] || [ ! -d "$home" ]; then
	echo "Error: the home directory of $owner does not exist." >&2
	exit 1
fi

# Refuse to take over an account or files that this lab did not create
if getent passwd deploy >/dev/null || getent group deploy >/dev/null; then
	echo "Error: user or group deploy already exists and was not created by this lab." >&2
	exit 1
fi
if [ -e /home/deploy ]; then
	echo "Error: /home/deploy already exists." >&2
	exit 1
fi
for f in "$home/.ssh/deploy_ed25519" "$home/.ssh/deploy_ed25519.pub"; do
	if [ -e "$f" ]; then
		echo "Error: $f already exists and was not created by this lab." >&2
		exit 1
	fi
done

# Record the state and back up the client files that exist now
mkdir -p "$STATE_DIR"
rm -rf "$BACKUP_DIR"
mkdir -m 700 "$BACKUP_DIR"
ssh_dir=0
[ -d "$home/.ssh" ] && ssh_dir=1
for f in $SAVED; do
	if [ -f "$home/.ssh/$f" ] && [ ! -L "$home/.ssh/$f" ]; then
		cp -p "$home/.ssh/$f" "$BACKUP_DIR/$f"
	fi
done
{
	echo "owner=$owner"
	echo "home=$home"
	echo "ssh_dir=$ssh_dir"
} > "$STATE_FILE"
chmod 644 "$STATE_FILE"

# The account deploy: a home directory, no password. "*" (not the "!!"
# of a new account) leaves key logins possible however sshd treats
# locked accounts.
useradd -m -c "ssh-01 lab account" deploy
usermod -p '*' deploy

exit 0
