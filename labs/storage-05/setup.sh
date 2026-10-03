#!/bin/bash
# storage-05 setup: builds the volume group growvg on the loop device of
# /srv/growvg/disk1.img with two logical volumes, xfslv (320 MiB, XFS,
# mounted on /mnt/xfsdata) and extlv (128 MiB, ext4, mounted on
# /mnt/extdata), writes a data file to each and records their checksums
# and file system UUIDs in the state file. It also creates the second
# image /srv/growvg/disk2.img, which the student attaches. The mounts are
# runtime only: the loop devices do not survive a reboot. Prints nothing
# on success. Only growvg and the loop devices of its images are
# touched; the volume group of the operating system never is.
set -eu

DIR=/srv/growvg
VG=growvg
STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/storage-05"

# Run a command quietly; on failure show its output and stop
q() {
	local out
	if ! out=$("$@" 2>&1); then
		echo "storage-05: setup failed: $*" >&2
		[ -z "$out" ] || printf '%s\n' "$out" >&2
		exit 1
	fi
}

for c in losetup pvcreate mkfs.xfs mkfs.ext4 xfs_growfs resize2fs; do
	if ! command -v "$c" >/dev/null 2>&1; then
		echo "storage-05: the command $c is missing (lvm2, xfsprogs and e2fsprogs are required)" >&2
		exit 1
	fi
done

# Refuse to remove a growvg that lives on something other than loop devices
if vgs --noheadings "$VG" >/dev/null 2>&1; then
	for pv in $(pvs --noheadings -o pv_name -S "vg_name=$VG" 2>/dev/null); do
		case "$pv" in
			/dev/loop*) ;;
			*)
				echo "storage-05: volume group $VG exists on $pv, not on a loop device. Refusing to remove it." >&2
				exit 1
				;;
		esac
	done
fi

# Remove what an earlier run or its solution left behind
bash "$(dirname "$0")/cleanup.sh"

for m in /mnt/xfsdata /mnt/extdata; do
	if mountpoint -q "$m" 2>/dev/null; then
		echo "storage-05: $m is already a mount point" >&2
		exit 1
	fi
done

mkdir -p "$DIR"
chmod 755 "$DIR"
q fallocate -l 512M "$DIR/disk1.img"
q fallocate -l 512M "$DIR/disk2.img"
chmod 600 "$DIR/disk1.img" "$DIR/disk2.img"

loop=$(losetup --find --show "$DIR/disk1.img")
q pvcreate -q "$loop"
q vgcreate -q "$VG" "$loop"
q lvcreate -q -y -W y -L 320M -n xfslv "$VG"
q lvcreate -q -y -W y -L 128M -n extlv "$VG"
udevadm settle >/dev/null 2>&1 || true
q mkfs.xfs -q -f "/dev/$VG/xfslv"
q mkfs.ext4 -q -F "/dev/$VG/extlv"

mkdir -p /mnt/xfsdata /mnt/extdata
q mount "/dev/$VG/xfslv" /mnt/xfsdata
q mount "/dev/$VG/extlv" /mnt/extdata

q dd if=/dev/urandom of=/mnt/xfsdata/records.bin bs=1M count=64 status=none
q dd if=/dev/urandom of=/mnt/extdata/records.bin bs=1M count=32 status=none
sync

xfs_sum=$(sha256sum /mnt/xfsdata/records.bin | cut -d' ' -f1)
ext_sum=$(sha256sum /mnt/extdata/records.bin | cut -d' ' -f1)
xfs_uuid=$(blkid -p -o value -s UUID "/dev/$VG/xfslv")
ext_uuid=$(blkid -p -o value -s UUID "/dev/$VG/extlv")

mkdir -p "$STATE_DIR"
{
	echo "xfs_sum=$xfs_sum"
	echo "ext_sum=$ext_sum"
	echo "xfs_uuid=$xfs_uuid"
	echo "ext_uuid=$ext_uuid"
} > "$STATE_FILE"
chmod 644 "$STATE_FILE"
