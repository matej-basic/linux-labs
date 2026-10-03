#!/bin/bash
# storage-10 cleanup: unmounts the file system of the lab array (and
# /mnt/raid), deletes the fstab lines of the lab, stops every md array
# on the lab disks, wipes the md superblocks of the loop devices so that
# udev cannot assemble the array again, detaches the loop devices of
# /srv/storage-10-disk1.img to disk3.img and removes the images, the
# mount point and the state, then restores the package set (pkg_restore
# removes mdadm if the lab brought it in) and /etc/mdadm.conf as it was
# at the first start (without a record it deletes the ARRAY lines of the
# lab). Safe to run repeatedly and on a lab that was never started.
#
# setup.sh runs this script with --leftovers: it then removes only what
# an earlier run left behind and keeps the package snapshot, the record
# of the first start and the state file.
source /opt/linux-labs/lib/packages.sh

STATE_FILE=/opt/linux-labs/state/storage-10
ORIG=/opt/linux-labs/state/storage-10.orig
MNT=/mnt/raid
IMGS="/srv/storage-10-disk1.img /srv/storage-10-disk2.img /srv/storage-10-disk3.img"

leftovers_only=no
[ "${1:-}" = --leftovers ] && leftovers_only=yes

# Loop devices of the lab images
loops=""
for img in $IMGS; do
	[ -e "$img" ] || continue
	for d in $(losetup -j "$img" -O NAME -n 2>/dev/null); do
		loops="$loops $d"
	done
done

# md arrays that hold a lab loop device
lab_arrays() {
	local d h out=""
	for d in $loops; do
		for h in /sys/block/"${d#/dev/}"/holders/md*; do
			[ -e "$h" ] || continue
			case " $out " in
				*" ${h##*/} "*) ;;
				*) out="$out ${h##*/}" ;;
			esac
		done
	done
	echo "$out"
}

arrays=$(lab_arrays)

# UUIDs of the arrays and of their file systems, for fstab and
# mdadm.conf
fs_uuids=""
md_uuids=""
for md in $arrays; do
	u=$(blkid -p -o value -s UUID "/dev/$md" 2>/dev/null)
	[ -n "$u" ] && fs_uuids="$fs_uuids $u"
	if command -v mdadm >/dev/null 2>&1; then
		u=$(mdadm --detail --export "/dev/$md" 2>/dev/null |
			sed -n 's/^MD_UUID=//p')
		[ -n "$u" ] && md_uuids="$md_uuids $u"
	fi
done

# Unmount the arrays and the lab mount point
for md in $arrays; do
	findmnt -rn -S "/dev/$md" -o TARGET 2>/dev/null | sort -ru | while read -r t; do
		umount "$t" >/dev/null 2>&1 || umount -l "$t" >/dev/null 2>&1
	done
done
src=$(findmnt -rn -M "$MNT" -o SOURCE 2>/dev/null | tail -n 1)
case "$src" in
	/dev/md* | /dev/loop*)
		umount "$MNT" >/dev/null 2>&1 || umount -l "$MNT" >/dev/null 2>&1 ;;
esac

# fstab lines of the lab: the file system by UUID or by the label
# RAIDDATA, an md device that held a lab disk, and any line for the
# mount point
if [ -f /etc/fstab ]; then
	awk -v uuids="$fs_uuids" -v mds="$arrays" -v mnt="$MNT" '
		BEGIN {
			n = split(uuids, u, " ")
			for (i = 1; i <= n; i++) want[toupper(u[i])] = 1
			n = split(mds, m, " ")
			for (i = 1; i <= n; i++) md["/dev/" m[i]] = 1
		}
		/^[[:space:]]*#/ || NF < 2 { print; next }
		{
			src = $1
			gsub(/"/, "", src)
			if (toupper(src) ~ /^UUID=/ && (toupper(substr(src, 6)) in want)) next
			if (src == "LABEL=RAIDDATA" || (src in md)) next
			if (src ~ /^\/dev\/md\/(.*:)?labraid$/) next
			if ($2 == mnt) next
			print
		}' /etc/fstab > /etc/fstab.storage-10.new
	if ! cmp -s /etc/fstab /etc/fstab.storage-10.new; then
		cat /etc/fstab.storage-10.new > /etc/fstab
	fi
	rm -f /etc/fstab.storage-10.new
fi
systemctl daemon-reload >/dev/null 2>&1 || true
unit=$(systemd-escape -p --suffix=mount "$MNT" 2>/dev/null)
[ -n "$unit" ] && systemctl reset-failed "$unit" >/dev/null 2>&1

# Stop the arrays, wipe the md superblocks of the lab disks, and repeat
# if udev assembled an array again in the meantime
stop_array() {
	if command -v mdadm >/dev/null 2>&1; then
		mdadm --stop "/dev/$1" >/dev/null 2>&1 && return 0
	fi
	[ -w "/sys/block/$1/md/array_state" ] &&
		echo clear > "/sys/block/$1/md/array_state" 2>/dev/null
}
for round in 1 2 3; do
	for md in $(lab_arrays); do
		stop_array "$md" || true
	done
	udevadm settle >/dev/null 2>&1 || true
	for d in $loops; do
		if command -v mdadm >/dev/null 2>&1; then
			mdadm --zero-superblock "$d" >/dev/null 2>&1 || true
		fi
		wipefs -a -q "$d" >/dev/null 2>&1 || true
	done
	udevadm settle >/dev/null 2>&1 || true
	[ -z "$(lab_arrays | tr -d ' ')" ] && break
	[ "$round" -lt 3 ] && sleep 1
done

# Detach every loop device of the images
for d in $loops; do
	losetup -d "$d" >/dev/null 2>&1 || true
done
udevadm settle >/dev/null 2>&1 || true

# shellcheck disable=SC2086 # three fixed paths without spaces
rm -f $IMGS
mountpoint -q "$MNT" 2>/dev/null || rm -rf "$MNT"

# /etc/mdadm.conf: back to the first start, or without a record (the
# lab was never started) only the ARRAY lines of the lab removed. The
# file belongs to no package.
restore_mdadm_conf() {
	if [ -e "$ORIG/recorded" ]; then
		if [ -e "$ORIG/mdadm.conf" ]; then
			cp --preserve=mode,ownership,timestamps "$ORIG/mdadm.conf" /etc/mdadm.conf
			restorecon /etc/mdadm.conf >/dev/null 2>&1 || true
		else
			rm -f /etc/mdadm.conf
		fi
	elif [ -f /etc/mdadm.conf ]; then
		awk -v uuids="$md_uuids" '
			BEGIN {
				n = split(uuids, u, " ")
				for (i = 1; i <= n; i++) want[toupper(u[i])] = 1
			}
			/^[^[:space:]]/ { skip = 0 }
			/^ARRAY[[:space:]]/ {
				line = toupper($0)
				if (line ~ /LABRAID/) skip = 1
				for (k in want) if (index(line, "UUID=" k)) skip = 1
			}
			skip && /^([[:space:]]|ARRAY)/ { next }
			{ print }' /etc/mdadm.conf > /etc/mdadm.conf.storage-10.new
		if ! cmp -s /etc/mdadm.conf /etc/mdadm.conf.storage-10.new; then
			cat /etc/mdadm.conf.storage-10.new > /etc/mdadm.conf
		fi
		rm -f /etc/mdadm.conf.storage-10.new
	fi
}

if [ "$leftovers_only" = yes ]; then
	restore_mdadm_conf
	exit 0
fi

rc=0
pkg_restore storage-10 || rc=1
restore_mdadm_conf
systemctl reset-failed mdmonitor.service >/dev/null 2>&1 || true
if [ "$rc" -eq 0 ]; then
	rm -f "$STATE_FILE"
	rm -rf "$ORIG"
fi
exit "$rc"
