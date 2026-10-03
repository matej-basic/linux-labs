#!/bin/bash
# storage-10 setup: records the package set and /etc/mdadm.conf (first
# start only), removes what an earlier run left behind, creates three
# sparse 400 MiB images /srv/storage-10-disk1.img to disk3.img, attaches
# each one to a loop device and writes the three loop device names as
# lines 1 to 3 of the state file. Prints nothing on success. Only the
# loop devices of the images are touched, never the disks of the system.
set -eu
source /opt/linux-labs/lib/packages.sh

STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/storage-10"
ORIG="$STATE_DIR/storage-10.orig"
MNT=/mnt/raid

fail() {
	echo "storage-10: $*" >&2
	exit 1
}

pkg_snapshot storage-10

for c in losetup blkid mkfs.xfs findmnt; do
	command -v "$c" >/dev/null 2>&1 ||
		fail "the command $c is missing (util-linux and xfsprogs are required)"
done

# /etc/mdadm.conf as it was at the first start, so that a restart keeps
# the original
if [ ! -e "$ORIG/recorded" ]; then
	rm -rf "$ORIG"
	mkdir -p "$ORIG"
	chmod 700 "$ORIG"
	if [ -e /etc/mdadm.conf ]; then
		cp -p /etc/mdadm.conf "$ORIG/mdadm.conf"
	fi
	touch "$ORIG/recorded"
fi

# Remove what an earlier run or its solution left behind
bash "$(dirname "$0")/cleanup.sh" --leftovers

if mountpoint -q "$MNT" 2>/dev/null; then
	fail "$MNT is a mount point of something else; refusing to start"
fi

# An array called labraid that is not on the lab disks belongs to
# something else
if command -v mdadm >/dev/null 2>&1; then
	for md in /sys/block/md*; do
		[ -e "$md/md" ] || continue
		name=$(mdadm --detail --export "/dev/${md##*/}" 2>/dev/null |
			sed -n 's/^MD_NAME=//p')
		case "$name" in
			labraid | *:labraid)
				fail "the md array ${md##*/} is called labraid and belongs to something else; refusing to start" ;;
		esac
	done
fi

modprobe loop >/dev/null 2>&1 || true
[ -e /dev/loop-control ] || fail "loop devices are not available on this system"

mkdir -p /srv
loops=""
for i in 1 2 3; do
	img="/srv/storage-10-disk$i.img"
	truncate -s 400M "$img"
	chmod 600 "$img"
	if ! loop=$(losetup --find --show "$img" 2>&1); then
		bash "$(dirname "$0")/cleanup.sh" --leftovers
		fail "cannot attach $img to a loop device: $loop"
	fi
	loops="$loops $loop"
done
udevadm settle >/dev/null 2>&1 || true

mkdir -p "$STATE_DIR"
# shellcheck disable=SC2086 # the three names, one per line
printf '%s\n' $loops > "$STATE_FILE"
chmod 644 "$STATE_FILE"
