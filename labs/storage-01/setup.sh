#!/bin/bash
# storage-01 setup: make sure no image, mount or fstab entry of the lab is
# left over, and that loop devices are available. Prints nothing on success.
set -eu

IMG=/srv/disk.img
MNT=/mnt/data

if [ -e "$MNT" ] && mountpoint -q "$MNT"; then
	# Only our own image may be unmounted here
	src=$(findmnt -n -o SOURCE --target "$MNT" 2>/dev/null || true)
	if [ -n "$src" ] && losetup -j "$IMG" 2>/dev/null | cut -d: -f1 | grep -qx "$src"; then
		umount "$MNT" || umount -l "$MNT"
	else
		echo "storage-01: $MNT is already a mount point of something else; refusing to start" >&2
		exit 1
	fi
fi

# Detach loop devices of the image
if [ -e "$IMG" ]; then
	for dev in $(losetup -j "$IMG" 2>/dev/null | cut -d: -f1); do
		losetup -d "$dev" 2>/dev/null || true
	done
fi
rm -f "$IMG"

# Remove leftover fstab entries of the lab
if grep -qE "^[^#]*([[:space:]]|^)(/srv/disk\.img|/tmp/disk\.img)[[:space:]]|^[^#[:space:]]+[[:space:]]+/mnt/data[[:space:]]" /etc/fstab; then
	awk '/^[[:space:]]*#/ { print; next }
	     $1 == "/srv/disk.img" || $1 == "/tmp/disk.img" || $2 == "/mnt/data" { next }
	     { print }' /etc/fstab > /etc/fstab.storage-01.new
	cat /etc/fstab.storage-01.new > /etc/fstab
	rm -f /etc/fstab.storage-01.new
	systemctl daemon-reload 2>/dev/null || true
fi
rm -f /tmp/disk.img

# Loop devices must be available
modprobe loop 2>/dev/null || true
if [ ! -e /dev/loop-control ]; then
	echo "storage-01: loop devices are not available on this system" >&2
	exit 1
fi
