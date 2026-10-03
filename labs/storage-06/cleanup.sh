#!/bin/bash
# storage-06 cleanup: turns off the swap on the lab disk, unmounts its
# file systems, deletes the fstab lines of its partitions (by UUID, by
# device name, by label) and of the mount points /mnt/archive and
# /mnt/exchange, detaches the loop devices of /srv/storage-06.img,
# removes the image, the mount points and the state file, then restores
# the package set (pkg_restore removes dosfstools if the lab brought it
# in). Safe to run repeatedly and on a lab that was never started.
#
# setup.sh runs this script with --leftovers: it then removes only what
# an earlier run left behind and keeps the package snapshot and the
# state file.
source /opt/linux-labs/lib/packages.sh

IMG=/srv/storage-06.img
STATE_FILE=/opt/linux-labs/state/storage-06
MNTS="/mnt/archive /mnt/exchange"

leftovers_only=no
[ "${1:-}" = --leftovers ] && leftovers_only=yes

loops=$( [ -e "$IMG" ] && losetup -j "$IMG" -O NAME -n 2>/dev/null)

# The image is not attached (for example after a reboot): attach it
# read-only for a moment, only to read the UUIDs of its partitions
probe_loop=""
if [ -e "$IMG" ] && [ -z "$loops" ]; then
	probe_loop=$(losetup --find --show --partscan --read-only "$IMG" 2>/dev/null)
	udevadm settle >/dev/null 2>&1 || true
fi

# Partitions of the lab disk and their UUIDs
parts=""
uuids=""
for d in $loops $probe_loop; do
	n=${d#/dev/}
	for p in /sys/block/"$n"/"$n"p*; do
		[ -e "$p" ] || continue
		parts="$parts /dev/${p##*/}"
		u=$(blkid -p -o value -s UUID "/dev/${p##*/}" 2>/dev/null)
		[ -n "$u" ] && uuids="$uuids $u"
	done
done

# Swap areas on the lab disk
for p in $parts; do
	if awk -v p="$p" 'NR > 1 && $1 == p { f = 1 } END { exit !f }' /proc/swaps; then
		swapoff "$p" >/dev/null 2>&1 || true
	fi
done

# Mounts from the lab disk and on the lab mount points
for p in $parts; do
	findmnt -rn -S "$p" -o TARGET 2>/dev/null | sort -ru | while read -r t; do
		umount "$t" >/dev/null 2>&1 || umount -l "$t" >/dev/null 2>&1
	done
done
for m in $MNTS; do
	src=$(findmnt -rn -M "$m" -o SOURCE 2>/dev/null | tail -n 1)
	case "$src" in
		/dev/loop*) umount "$m" >/dev/null 2>&1 || umount -l "$m" >/dev/null 2>&1 ;;
	esac
done

# fstab lines of the lab: the partitions by UUID (with or without
# quotes, any case), by loop device name or by the label ARCHIVE, and
# any line for the two mount points
if [ -f /etc/fstab ]; then
	awk -v uuids="$uuids" -v mnts="$MNTS" '
		BEGIN {
			n = split(uuids, u, " ")
			for (i = 1; i <= n; i++) want[toupper(u[i])] = 1
			n = split(mnts, m, " ")
			for (i = 1; i <= n; i++) mnt[m[i]] = 1
		}
		/^[[:space:]]*#/ || NF < 2 { print; next }
		{
			src = $1
			gsub(/"/, "", src)
			if (toupper(src) ~ /^UUID=/ && (toupper(substr(src, 6)) in want)) next
			if (src ~ /^\/dev\/loop[0-9]+p[0-9]+$/) next
			if (src == "LABEL=ARCHIVE") next
			if ($2 in mnt) next
			print
		}' /etc/fstab > /etc/fstab.storage-06.new
	if ! cmp -s /etc/fstab /etc/fstab.storage-06.new; then
		cat /etc/fstab.storage-06.new > /etc/fstab
	fi
	rm -f /etc/fstab.storage-06.new
fi
systemctl daemon-reload >/dev/null 2>&1 || true
for u in $uuids; do
	for s in swap mount; do
		unit=$(systemd-escape -p --suffix="$s" "/dev/disk/by-uuid/$u" 2>/dev/null)
		[ -n "$unit" ] && systemctl reset-failed "$unit" >/dev/null 2>&1
	done
done
for m in $MNTS; do
	unit=$(systemd-escape -p --suffix=mount "$m" 2>/dev/null)
	[ -n "$unit" ] && systemctl reset-failed "$unit" >/dev/null 2>&1
done

# Detach every loop device of the image
for d in $loops $probe_loop; do
	losetup -d "$d" >/dev/null 2>&1 || true
done
udevadm settle >/dev/null 2>&1 || true

rm -f "$IMG"
for m in $MNTS; do
	mountpoint -q "$m" 2>/dev/null || rm -rf "$m"
done

[ "$leftovers_only" = yes ] && exit 0

rc=0
pkg_restore storage-06 || rc=1
[ "$rc" -eq 0 ] && rm -f "$STATE_FILE"
exit "$rc"
