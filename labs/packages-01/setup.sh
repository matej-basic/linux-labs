#!/bin/bash
# packages-01 setup: make sure git is not installed. Prints nothing on
# success.
set -eu

STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/packages-01"

if rpm -q git &>/dev/null; then
	if ! dnf -y remove git &>/dev/null; then
		echo "packages-01: could not remove the git package" >&2
		exit 1
	fi
fi

mkdir -p "$STATE_DIR"
date +%s > "$STATE_FILE"
chmod 644 "$STATE_FILE"
