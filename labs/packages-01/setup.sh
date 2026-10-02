#!/bin/bash
# packages-01 setup: make sure git is not installed. Prints nothing on
# success. Records whether git was installed before the first run, so
# that cleanup.sh can put it back.
set -eu

STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/packages-01"
PRE=/var/tmp/packages-01.pre

# Only the first run sees the real starting state
if [ ! -f "$PRE" ]; then
	if rpm -q git &>/dev/null; then
		echo git-installed > "$PRE"
	else
		echo git-missing > "$PRE"
	fi
fi

if rpm -q git &>/dev/null; then
	if ! dnf -y remove git &>/dev/null; then
		echo "packages-01: could not remove the git package" >&2
		exit 1
	fi
fi

mkdir -p "$STATE_DIR"
date +%s > "$STATE_FILE"
chmod 644 "$STATE_FILE"
