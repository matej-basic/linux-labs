#!/bin/bash
# ssh-01 cleanup: removes the account deploy, the key pair and puts the
# task user's SSH client files (config, known_hosts) back as they were
# before the lab.
LAB=ssh-01
STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/$LAB"
BACKUP_DIR="$STATE_DIR/$LAB.d"
SAVED="config known_hosts known_hosts.old"

# Without the state file the lab did not start: leave accounts alone
if [ -f "$STATE_FILE" ]; then
	home=$(sed -n 's/^home=//p' "$STATE_FILE")
	ssh_dir=$(sed -n 's/^ssh_dir=//p' "$STATE_FILE")

	if getent passwd deploy >/dev/null; then
		pkill -KILL -u deploy >/dev/null 2>&1
		userdel -r -f deploy >/dev/null 2>&1
	fi
	groupdel deploy >/dev/null 2>&1
	rm -rf /home/deploy

	if [ -n "$home" ] && [ -d "$home/.ssh" ]; then
		rm -f "$home/.ssh/deploy_ed25519" "$home/.ssh/deploy_ed25519.pub"
		for f in $SAVED; do
			if [ -f "$BACKUP_DIR/$f" ]; then
				rm -f "$home/.ssh/$f"
				cp -p "$BACKUP_DIR/$f" "$home/.ssh/$f"
				restorecon "$home/.ssh/$f" >/dev/null 2>&1
			else
				rm -f "$home/.ssh/$f"
			fi
		done
		# ~/.ssh did not exist before the lab: remove it if it is empty
		if [ "$ssh_dir" = 0 ]; then
			rmdir "$home/.ssh" >/dev/null 2>&1
		fi
	fi
fi

rm -rf "$BACKUP_DIR"
rm -f "$STATE_FILE"
exit 0
