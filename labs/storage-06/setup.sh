#!/bin/bash
# storage-06 setup: records the package set, removes what an earlier run
# left behind (swap, mounts, fstab lines, loop devices of the image),
# creates the sparse 1 GiB image /srv/storage-06.img, attaches it to a
# loop device with partition scanning and writes the loop device name as
# the first line of the state file. Prints nothing on success. Only the
# loop device of the image is touched, never the disk of the system.
set -eu
source /opt/linux-labs/lib/packages.sh

IMG=/srv/storage-06.img
STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/storage-06"

pkg_snapshot storage-06

for c in losetup blkid parted mkfs.xfs mkswap; do
	if ! command -v "$c" >/dev/null 2>&1; then
		echo "storage-06: the command $c is missing (util-linux, parted and xfsprogs are required)" >&2
		exit 1
	fi
done

# Remove what an earlier run or its solution left behind
bash "$(dirname "$0")/cleanup.sh" --leftovers

for m in /mnt/archive /mnt/exchange; do
	if mountpoint -q "$m" 2>/dev/null; then
		echo "storage-06: $m is a mount point of something else; refusing to start" >&2
		exit 1
	fi
done

modprobe loop >/dev/null 2>&1 || true
if [ ! -e /dev/loop-control ]; then
	echo "storage-06: loop devices are not available on this system" >&2
	exit 1
fi

mkdir -p /srv
truncate -s 1G "$IMG"
chmod 600 "$IMG"
if ! loop=$(losetup --find --show --partscan "$IMG" 2>&1); then
	echo "storage-06: cannot attach $IMG to a loop device: $loop" >&2
	rm -f "$IMG"
	exit 1
fi
udevadm settle >/dev/null 2>&1 || true

mkdir -p "$STATE_DIR"
printf '%s\n' "$loop" > "$STATE_FILE"
chmod 644 "$STATE_FILE"
