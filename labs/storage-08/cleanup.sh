#!/bin/bash
# storage-08 cleanup: removes the fstab lines of the lab (the image path,
# the UUID of the file system in the image, the mount point
# /srv/projects), unmounts /srv/projects, detaches the loop devices of
# /srv/storage-08.img, removes the image, /srv/projects, the users qalice
# and qbob with their homes and mail spools, the group qteam and the
# state file. Safe to run repeatedly and on a lab that was never started.
# setup.sh runs it first to remove what an earlier run left behind.
IMG=/srv/storage-08.img
MNT=/srv/projects
STATE_FILE=/opt/linux-labs/state/storage-08

loops=$( [ -e "$IMG" ] && losetup -j "$IMG" -O NAME -n 2>/dev/null)
uuid=$( [ -e "$IMG" ] && blkid -p -o value -s UUID "$IMG" 2>/dev/null)

# fstab lines of the lab: by image path, by the UUID of its file system
# (with or without quotes, any case), by loop device name, and any line
# for the mount point
if [ -f /etc/fstab ]; then
	awk -v img="$IMG" -v mnt="$MNT" -v uuid="$uuid" '
		/^[[:space:]]*#/ || NF < 2 { print; next }
		{
			src = $1
			gsub(/"/, "", src)
			if (src == img || $2 == mnt) next
			if (uuid != "" && toupper(src) == toupper("UUID=" uuid)) next
			print
		}' /etc/fstab > /etc/fstab.storage-08.new
	if [ -s /etc/fstab.storage-08.new ] &&
		! cmp -s /etc/fstab /etc/fstab.storage-08.new; then
		cat /etc/fstab.storage-08.new > /etc/fstab
	fi
	rm -f /etc/fstab.storage-08.new
fi

# Unmount everything that sits on a loop device of the image, then the
# mount point itself if a loop device is mounted there
for d in $loops; do
	findmnt -rn -S "$d" -o TARGET 2>/dev/null | sort -ru | while read -r t; do
		umount "$t" >/dev/null 2>&1 || umount -l "$t" >/dev/null 2>&1
	done
done
src=$(findmnt -rn -M "$MNT" -o SOURCE 2>/dev/null | tail -n 1)
case "$src" in
	/dev/loop*) umount "$MNT" >/dev/null 2>&1 || umount -l "$MNT" >/dev/null 2>&1 ;;
esac

for d in $loops; do
	losetup -d "$d" >/dev/null 2>&1 || true
done
udevadm settle >/dev/null 2>&1 || true

systemctl daemon-reload >/dev/null 2>&1 || true
unit=$(systemd-escape -p --suffix=mount "$MNT" 2>/dev/null)
[ -n "$unit" ] && systemctl reset-failed "$unit" >/dev/null 2>&1

rm -f "$IMG"
mountpoint -q "$MNT" 2>/dev/null || rm -rf "$MNT"

# Lab users and group
for u in qalice qbob; do
	if getent passwd "$u" >/dev/null; then
		pkill -KILL -u "$u" >/dev/null 2>&1 || true
		userdel -r "$u" >/dev/null 2>&1 || userdel -f "$u" >/dev/null 2>&1 || true
	fi
	rm -rf "/home/${u:?}"
	rm -f "/var/spool/mail/$u"
done
for g in qteam qalice qbob; do
	if getent group "$g" >/dev/null; then
		groupdel "$g" >/dev/null 2>&1 || true
	fi
done

rm -f "$STATE_FILE"
exit 0
