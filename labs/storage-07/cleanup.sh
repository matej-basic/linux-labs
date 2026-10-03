#!/bin/bash
# storage-07 cleanup: unmounts and closes every device mapping on the
# lab disk (and /mnt/secure), deletes the fstab lines of the lab,
# restores /etc/crypttab as it was at the first start (without a record
# it deletes the securedata line), removes /etc/luks-keys if the lab
# created it (else only the key file), detaches the loop devices of
# /srv/storage-07.img and removes the image, the mount point, the
# passphrase file and the state, then restores the package set
# (pkg_restore removes cryptsetup if the lab brought it in). Safe to run
# repeatedly and on a lab that was never started.
#
# setup.sh runs this script with --leftovers: it then removes only what
# an earlier run left behind and keeps the package snapshot, the record
# of the first start and the state file.
source /opt/linux-labs/lib/packages.sh

IMG=/srv/storage-07.img
STATE_FILE=/opt/linux-labs/state/storage-07
ORIG=/opt/linux-labs/state/storage-07.orig
MNT=/mnt/secure
NAME=securedata
KEYDIR=/etc/luks-keys
KEY="$KEYDIR/secret.key"

leftovers_only=no
[ "${1:-}" = --leftovers ] && leftovers_only=yes

loops=$( [ -e "$IMG" ] && losetup -j "$IMG" -O NAME -n 2>/dev/null)

# Device mappings on the lab disk (dm-N holders of its loop devices),
# and securedata itself
maps=""
add_map() {
	case " $maps " in
		*" $1 "*) ;;
		*) maps="$maps $1" ;;
	esac
}
for d in $loops; do
	for h in /sys/block/"${d#/dev/}"/holders/*; do
		[ -e "$h/dm/name" ] && add_map "$(cat "$h/dm/name")"
	done
done
[ -e "/dev/mapper/$NAME" ] && add_map "$NAME"

# UUIDs of the file systems in the mappings, for the fstab lines
uuids=""
for m in $maps; do
	u=$(blkid -p -o value -s UUID "/dev/mapper/$m" 2>/dev/null)
	[ -n "$u" ] && uuids="$uuids $u"
done

# Unmount the mappings and the lab mount point
for m in $maps; do
	findmnt -rn -S "/dev/mapper/$m" -o TARGET 2>/dev/null | sort -ru | while read -r t; do
		umount "$t" >/dev/null 2>&1 || umount -l "$t" >/dev/null 2>&1
	done
done
src=$(findmnt -rn -M "$MNT" -o SOURCE 2>/dev/null | tail -n 1)
case "$src" in
	/dev/mapper/* | /dev/dm-* | /dev/loop*)
		umount "$MNT" >/dev/null 2>&1 || umount -l "$MNT" >/dev/null 2>&1 ;;
esac

# Close the mappings (a unit from crypttab first, if it holds one)
for m in $maps; do
	unit=$(systemd-escape --template=systemd-cryptsetup@.service "$m" 2>/dev/null)
	[ -n "$unit" ] && systemctl stop "$unit" >/dev/null 2>&1
	if [ -e "/dev/mapper/$m" ]; then
		cryptsetup close "$m" >/dev/null 2>&1 ||
			dmsetup remove "$m" >/dev/null 2>&1 || true
	fi
done

# fstab lines of the lab: the mapping by name, the file system by UUID
# or by the label SECURE, and any line for the mount point
if [ -f /etc/fstab ]; then
	awk -v uuids="$uuids" -v mnt="$MNT" -v name="$NAME" '
		BEGIN {
			n = split(uuids, u, " ")
			for (i = 1; i <= n; i++) want[toupper(u[i])] = 1
		}
		/^[[:space:]]*#/ || NF < 2 { print; next }
		{
			src = $1
			gsub(/"/, "", src)
			if (toupper(src) ~ /^UUID=/ && (toupper(substr(src, 6)) in want)) next
			if (src == "/dev/mapper/" name || src == "LABEL=SECURE") next
			if ($2 == mnt) next
			print
		}' /etc/fstab > /etc/fstab.storage-07.new
	if ! cmp -s /etc/fstab /etc/fstab.storage-07.new; then
		cat /etc/fstab.storage-07.new > /etc/fstab
	fi
	rm -f /etc/fstab.storage-07.new
fi

# /etc/crypttab: back to the first start, or without a record (the lab
# was never started) only the line of the lab removed
if [ -e "$ORIG/recorded" ]; then
	if [ -e "$ORIG/crypttab" ]; then
		cp --preserve=mode,ownership,timestamps "$ORIG/crypttab" /etc/crypttab
		restorecon /etc/crypttab >/dev/null 2>&1 || true
	else
		rm -f /etc/crypttab
	fi
elif [ -f /etc/crypttab ]; then
	awk -v name="$NAME" '
		/^[[:space:]]*#/ || NF < 1 { print; next }
		$1 == name { next }
		{ print }' /etc/crypttab > /etc/crypttab.storage-07.new
	if ! cmp -s /etc/crypttab /etc/crypttab.storage-07.new; then
		cat /etc/crypttab.storage-07.new > /etc/crypttab
	fi
	rm -f /etc/crypttab.storage-07.new
fi

systemctl daemon-reload >/dev/null 2>&1 || true
for m in $maps $NAME; do
	unit=$(systemd-escape --template=systemd-cryptsetup@.service "$m" 2>/dev/null)
	[ -n "$unit" ] && systemctl reset-failed "$unit" >/dev/null 2>&1
done
unit=$(systemd-escape -p --suffix=mount "$MNT" 2>/dev/null)
[ -n "$unit" ] && systemctl reset-failed "$unit" >/dev/null 2>&1

# The key file and its directory, as far as the lab created them
if [ -e "$ORIG/recorded" ]; then
	if [ ! -e "$ORIG/keydir-existed" ]; then
		rm -rf "$KEYDIR"
	elif [ ! -e "$ORIG/key-existed" ]; then
		rm -f "$KEY"
	fi
fi

# Detach every loop device of the image
for d in $loops; do
	losetup -d "$d" >/dev/null 2>&1 || true
done
udevadm settle >/dev/null 2>&1 || true

rm -f "$IMG" /root/luks-passphrase
mountpoint -q "$MNT" 2>/dev/null || rm -rf "$MNT"

[ "$leftovers_only" = yes ] && exit 0

rc=0
pkg_restore storage-07 || rc=1
if [ "$rc" -eq 0 ]; then
	rm -f "$STATE_FILE"
	rm -rf "$ORIG"
fi
exit "$rc"
