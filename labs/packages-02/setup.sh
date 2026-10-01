#!/bin/bash
# packages-02 setup: remove EPEL and htop so the lab starts from a
# clean state. What was installed before is recorded in the state file
# and restored by cleanup.sh. Prints nothing on success.
set -eu

STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/packages-02"
BACKUP_DIR="$STATE_DIR/packages-02.repos"

command -v dnf >/dev/null 2>&1 || { echo "setup: dnf not found" >&2; exit 1; }

mkdir -p "$STATE_DIR"

# A repeated start keeps the state of the first one: by then the
# packages are already gone and would be recorded as "not installed".
if [ ! -f "$STATE_FILE" ]; then
	epel_pre=no
	htop_pre=no
	rpm -q epel-release >/dev/null 2>&1 && epel_pre=yes
	rpm -q htop >/dev/null 2>&1 && htop_pre=yes
	rm -rf "$BACKUP_DIR"
	if [ "$epel_pre" = yes ]; then
		mkdir -p "$BACKUP_DIR"
		cp -p /etc/yum.repos.d/epel*.repo "$BACKUP_DIR"/ 2>/dev/null || true
	fi
	printf 'epel_pre=%s\nhtop_pre=%s\n' "$epel_pre" "$htop_pre" > "$STATE_FILE"
	chmod 644 "$STATE_FILE"
fi

if rpm -q htop >/dev/null 2>&1; then
	dnf -y -q remove htop >/dev/null 2>&1 || { echo "setup: cannot remove htop" >&2; exit 1; }
fi
if rpm -q epel-release >/dev/null 2>&1; then
	dnf -y -q remove epel-release >/dev/null 2>&1 || { echo "setup: cannot remove epel-release" >&2; exit 1; }
fi
# Repo files a student created by hand
rm -f /etc/yum.repos.d/epel*.repo
exit 0
