#!/bin/bash
# storage-11 cleanup: stops and removes app-logger.service and its
# script, unmounts /srv/appdata and /srv/archive when they are mounted
# from the lab images, detaches every loop device of the images,
# removes the fstab lines of the lab and puts /etc/fstab back exactly as
# it was at the first start, then removes the images, the mount points
# and the state, and restores the package set (in case lsof or another
# tool was installed during the lab). Safe to run repeatedly and on a
# lab that was never started.
#
# setup.sh runs this script with --leftovers: it then removes only what
# an earlier run left behind (the fstab lines of the lab by pattern) and
# keeps the package snapshot and the record of the first start.
source /opt/linux-labs/lib/packages.sh

STATE_DIR=/opt/linux-labs/state
STATE=$STATE_DIR/storage-11
ORIG=$STATE_DIR/storage-11.orig
APP_IMG=/srv/storage-11-appdata.img
ARC_IMG=/srv/storage-11-archive.img
APP_MNT=/srv/appdata
ARC_MNT=/srv/archive
UNIT=/etc/systemd/system/app-logger.service
SCRIPT=/usr/local/bin/app-logger

leftovers_only=no
[ "${1:-}" = --leftovers ] && leftovers_only=yes

# The service first, so that nothing keeps the file system busy
if [ -e "$UNIT" ] || systemctl cat app-logger.service >/dev/null 2>&1; then
	systemctl disable --now app-logger.service >/dev/null 2>&1 || true
fi
rm -f "$UNIT" "$SCRIPT"
rm -f /etc/systemd/system/multi-user.target.wants/app-logger.service
rm -rf /etc/systemd/system/app-logger.service.d
systemctl daemon-reload >/dev/null 2>&1 || true
systemctl reset-failed app-logger.service >/dev/null 2>&1 || true

# True when the source of the mount on $1 is a loop device of image $2
mounted_from() {
	local src dev
	src=$(findmnt -rn -M "$1" -o SOURCE 2>/dev/null | tail -n 1)
	case "$src" in /dev/loop*) ;; *) return 1 ;; esac
	dev=${src#/dev/}
	[ "$(cat "/sys/block/$dev/loop/backing_file" 2>/dev/null)" = "$2" ]
}

for pair in "$APP_MNT:$APP_IMG" "$ARC_MNT:$ARC_IMG"; do
	mnt=${pair%%:*}
	img=${pair#*:}
	for _ in 1 2 3; do
		mounted_from "$mnt" "$img" || break
		umount "$mnt" >/dev/null 2>&1 || umount -l "$mnt" >/dev/null 2>&1 || true
	done
	# Any other mount of the image (the student may have used another
	# mount point)
	if [ -e "$img" ]; then
		for d in $(losetup -j "$img" -O NAME -n 2>/dev/null); do
			findmnt -rn -S "$d" -o TARGET 2>/dev/null | sort -ru |
				while read -r t; do
					umount "$t" >/dev/null 2>&1 || umount -l "$t" >/dev/null 2>&1
				done
			losetup -d "$d" >/dev/null 2>&1 || true
		done
	fi
done

# fstab lines of the lab: the image paths and the two mount points
if [ -f /etc/fstab ]; then
	awk -v a="$APP_IMG" -v b="$ARC_IMG" -v m1="$APP_MNT" -v m2="$ARC_MNT" '
		/^[[:space:]]*#/ || NF < 2 { print; next }
		$1 == a || $1 == b || $2 == m1 || $2 == m2 { next }
		{ print }' /etc/fstab > /etc/fstab.storage-11.new
	if ! cmp -s /etc/fstab /etc/fstab.storage-11.new; then
		cat /etc/fstab.storage-11.new > /etc/fstab
	fi
	rm -f /etc/fstab.storage-11.new
fi

rm -f "$APP_IMG" "$ARC_IMG"
for mnt in "$APP_MNT" "$ARC_MNT"; do
	mountpoint -q "$mnt" 2>/dev/null || rm -rf "$mnt"
done

if [ "$leftovers_only" = yes ]; then
	systemctl daemon-reload >/dev/null 2>&1 || true
	exit 0
fi

# /etc/fstab exactly as it was at the first start
if [ -f "$ORIG/fstab" ]; then
	if ! cmp -s "$ORIG/fstab" /etc/fstab; then
		cat "$ORIG/fstab" > /etc/fstab
	fi
fi
systemctl daemon-reload >/dev/null 2>&1 || true
for mnt in "$APP_MNT" "$ARC_MNT"; do
	systemctl reset-failed "$(systemd-escape -p --suffix=mount "$mnt")" >/dev/null 2>&1 || true
done

rc=0
pkg_restore storage-11 || rc=1
rm -rf "$STATE"
[ "$rc" -eq 0 ] && rm -rf "$ORIG"
exit "$rc"
