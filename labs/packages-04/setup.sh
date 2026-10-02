#!/bin/bash
# packages-04 setup: make sure joe is not installed and record the newest
# dnf history transaction, so the grader only looks at what happens after
# the start. Prints nothing on success.
set -eu
source /opt/linux-labs/lib/packages.sh

STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/packages-04"

if ! command -v dnf &>/dev/null; then
	echo "packages-04: dnf not found" >&2
	exit 1
fi

# First start only: record the package set before any dnf change
pkg_snapshot packages-04

# The joe editor must not be installed at the start
if rpm -q joe &>/dev/null; then
	dnf -y remove joe &>/dev/null || {
		echo "packages-04: cannot remove the joe package" >&2
		exit 1
	}
fi

# Newest dnf history transaction id (0 on a system without history)
start_id=$(LANG=C dnf history list 2>/dev/null | awk '$1 ~ /^[0-9]+$/ {print $1}' | sort -n | tail -n 1)

mkdir -p "$STATE_DIR" || exit 1
echo "${start_id:-0}" > "$STATE_FILE" || exit 1
chmod 0644 "$STATE_FILE"
