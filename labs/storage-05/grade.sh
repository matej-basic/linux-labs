#!/bin/bash
# storage-05 grader
source /opt/linux-labs/lib/grading.sh

DIR=/srv/growvg
VG=growvg
STATE_FILE=/opt/linux-labs/state/storage-05
MIB=1048576

grade_begin storage-05
grade_require_state storage-05 "$STATE_FILE"

state() {
	sed -n "s/^$1=//p" "$STATE_FILE" | head -n 1
}

img_loops() {
	losetup -j "$1" -O NAME -n 2>/dev/null
}

vg_pvs() {
	pvs --noheadings -o pv_name -S "vg_name=$VG" 2>/dev/null | awk '{ print $1 }'
}

two_pvs() {
	[ "$(vg_pvs | grep -c .)" -eq 2 ]
}

# A loop device of the image is a physical volume of growvg
image_in_vg() {
	local d
	for d in $(img_loops "$1"); do
		vg_pvs | grep -qx "$d" && return 0
	done
	return 1
}

lv_bytes() {
	lvs --noheadings --nosuffix --units b -o lv_size "$VG/$1" 2>/dev/null | tr -d ' '
}

lv_at_least() {
	local b
	b=$(lv_bytes "$1")
	[ -n "$b" ] && [ "$b" -ge "$2" ]
}

# Size of the file system from its superblock, in bytes
xfs_bytes() {
	xfs_info "$1" 2>/dev/null | awk '
		/^data/ {
			for (i = 1; i <= NF; i++) {
				if ($i ~ /^bsize=/) { split($i, a, "="); bs = a[2] }
				if ($i ~ /^blocks=/) { split($i, b, "="); sub(/,$/, "", b[2]); n = b[2] }
			}
			print bs * n
			exit
		}'
}

ext4_bytes() {
	dumpe2fs -h "$1" 2>/dev/null | awk -F: '
		/^Block count/ { n = $2 + 0 }
		/^Block size/ { bs = $2 + 0 }
		END { print n * bs }'
}

# The file system covers the whole LV (4 MiB tolerance)
fs_fills_lv() {
	local lv=$1 fs lvb
	lvb=$(lv_bytes "$lv")
	[ -n "$lvb" ] || return 1
	case "$2" in
		xfs) fs=$(xfs_bytes "$3") ;;
		ext4) fs=$(ext4_bytes "/dev/$VG/$lv") ;;
	esac
	[ -n "$fs" ] && [ "$fs" -gt 0 ] && [ "$fs" -ge $((lvb - 4 * MIB)) ]
}

# Mounted on the path from the LV, with the given type and the
# original file system UUID
mounted_ok() {
	local mnt=$1 lv=$2 type=$3 uuid=$4 src
	src=$(findmnt -rn -M "$mnt" -o SOURCE 2>/dev/null | tail -n 1)
	[ -n "$src" ] || return 1
	[ "$(readlink -f "$src")" = "$(readlink -f "/dev/$VG/$lv")" ] || return 1
	[ "$(findmnt -rn -M "$mnt" -o FSTYPE 2>/dev/null | tail -n 1)" = "$type" ] || return 1
	[ "$(blkid -p -o value -s UUID "/dev/$VG/$lv" 2>/dev/null)" = "$uuid" ]
}

data_intact() {
	[ -f "$1" ] && [ "$(sha256sum "$1" 2>/dev/null | cut -d' ' -f1)" = "$2" ]
}

xfs_uuid=$(state xfs_uuid)
ext_uuid=$(state ext_uuid)

criterion "Volume group $VG has two physical volumes" two_pvs
criterion "The loop device of disk1.img is a PV of $VG" image_in_vg "$DIR/disk1.img"
criterion "The loop device of disk2.img is a PV of $VG" image_in_vg "$DIR/disk2.img"
criterion "Logical volume xfslv is at least 512 MiB" lv_at_least xfslv $((512 * MIB))
criterion "Logical volume extlv is at least 256 MiB" lv_at_least extlv $((256 * MIB))
criterion "The original XFS file system is mounted on /mnt/xfsdata" mounted_ok /mnt/xfsdata xfslv xfs "$xfs_uuid"
criterion "The original ext4 file system is mounted on /mnt/extdata" mounted_ok /mnt/extdata extlv ext4 "$ext_uuid"
criterion "The XFS file system fills xfslv" fs_fills_lv xfslv xfs /mnt/xfsdata
criterion "The ext4 file system fills extlv" fs_fills_lv extlv ext4
criterion "/mnt/xfsdata/records.bin is unchanged" data_intact /mnt/xfsdata/records.bin "$(state xfs_sum)"
criterion "/mnt/extdata/records.bin is unchanged" data_intact /mnt/extdata/records.bin "$(state ext_sum)"
grade_end
