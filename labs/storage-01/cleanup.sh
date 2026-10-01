#!/bin/bash
# storage-01 cleanup: unmount /mnt/data, detach the loop device, remove the
# image, the mount point and the fstab entry. Safe to run repeatedly.
IMG=/srv/disk.img
MNT=/mnt/data

# Drop the fstab entry first so nothing remounts the image
if grep -qE "^[[:space:]]*[^#[:space:]]+[[:space:]]+/mnt/data[[:space:]]|^[[:space:]]*(/srv|/tmp)/disk\.img[[:space:]]" /etc/fstab 2>/dev/null; then
	awk '/^[[:space:]]*#/ { print; next }
	     $1 == "/srv/disk.img" || $1 == "/tmp/disk.img" || $2 == "/mnt/data" { next }
	     { print }' /etc/fstab > /etc/fstab.storage-01.new &&
		cat /etc/fstab.storage-01.new > /etc/fstab
	rm -f /etc/fstab.storage-01.new
fi

# Unmount everything that sits on a loop device of the image, then detach
for img in "$IMG" /tmp/disk.img; do
	[ -e "$img" ] || continue
	for dev in $(losetup -j "$img" 2>/dev/null | cut -d: -f1); do
		for target in $(findmnt -rn -S "$dev" -o TARGET 2>/dev/null); do
			umount "$target" 2>/dev/null || umount -l "$target" 2>/dev/null || true
		done
		losetup -d "$dev" 2>/dev/null || true
	done
done

# The mount point may be mounted from an already detached device
if mountpoint -q "$MNT" 2>/dev/null; then
	umount "$MNT" 2>/dev/null || umount -l "$MNT" 2>/dev/null || true
fi

rm -f "$IMG" /tmp/disk.img
mountpoint -q "$MNT" 2>/dev/null || rmdir "$MNT" 2>/dev/null || true
systemctl daemon-reload 2>/dev/null || true
exit 0
