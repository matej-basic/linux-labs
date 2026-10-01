#!/bin/bash
# storage-02 setup: removes leftovers of an earlier run and records the
# start in the state file. Prints nothing on success.
set -eu

STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/storage-02"
dir=$(dirname "$0")

if ! command -v pvcreate >/dev/null 2>&1; then
	dnf -y -q install lvm2 >/dev/null 2>&1 || {
		echo "storage-02: lvm2 is not installed and could not be installed" >&2
		exit 1
	}
fi

# Remove what an earlier run or its solution left behind
bash "$dir/cleanup.sh"

# Refuse to continue if datavg exists on real disks (not ours to remove)
if vgs --noheadings datavg >/dev/null 2>&1; then
	echo "storage-02: volume group datavg already exists on non-loop devices" >&2
	exit 1
fi
if mountpoint -q /mnt/lvm; then
	echo "storage-02: /mnt/lvm is already a mount point" >&2
	exit 1
fi

mkdir -p "$STATE_DIR"
date +%s > "$STATE_FILE"
chmod 644 "$STATE_FILE"
