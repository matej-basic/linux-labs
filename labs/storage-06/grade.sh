#!/bin/bash
# storage-06 grader
source /opt/linux-labs/lib/grading.sh

IMG=/srv/storage-06.img
STATE_FILE=/opt/linux-labs/state/storage-06
MIB=1048576

grade_begin storage-06
grade_require_state storage-06 "$STATE_FILE"

# The loop device of the image right now (the student may have attached
# it again under another name), else the one from the state file
loop=$(losetup -j "$IMG" -O NAME -n 2>/dev/null | head -n 1)
[ -n "$loop" ] || loop=$(head -n 1 "$STATE_FILE")
n=${loop#/dev/}

part() {
	echo "/dev/${n}p$1"
}

image_attached() {
	[ -e "$IMG" ] && losetup -j "$IMG" -O NAME -n 2>/dev/null | grep -q .
}

gpt_label() {
	image_attached || return 1
	[ "$(blkid -p -o value -s PTTYPE "$loop" 2>/dev/null)" = gpt ]
}

# Partitions as the kernel sees them, from sysfs (udev can lag)
three_partitions() {
	local p count=0
	image_attached || return 1
	for p in /sys/block/"$n"/"$n"p*; do
		[ -e "$p/partition" ] && count=$((count + 1))
	done
	[ "$count" -eq 3 ] && [ -e "/sys/block/$n/${n}p1" ] &&
		[ -e "/sys/block/$n/${n}p2" ] && [ -e "/sys/block/$n/${n}p3" ]
}

# Partition <num> is <mib> MiB (10 MiB tolerance) and holds <type>
part_ok() {
	local num=$1 mib=$2 type=$3 sectors bytes
	image_attached || return 1
	sectors=$(cat "/sys/block/$n/${n}p$num/size" 2>/dev/null) || return 1
	bytes=$((sectors * 512))
	[ "$bytes" -ge $(((mib - 10) * MIB)) ] &&
		[ "$bytes" -le $(((mib + 10) * MIB)) ] || return 1
	[ "$(blkid -p -o value -s TYPE "$(part "$num")" 2>/dev/null)" = "$type" ]
}

xfs_label() {
	image_attached || return 1
	[ "$(blkid -p -o value -s LABEL "$(part 1)" 2>/dev/null)" = ARCHIVE ]
}

mounted_from() {
	local src
	image_attached || return 1
	src=$(findmnt -rn -M "$1" -o SOURCE 2>/dev/null | tail -n 1)
	[ -n "$src" ] &&
		[ "$(readlink -f "$src")" = "$(readlink -f "$(part "$2")")" ]
}

swap_active() {
	image_attached || return 1
	awk -v p="$(part 2)" 'NR > 1 && $1 == p { f = 1 } END { exit !f }' /proc/swaps
}

# An active fstab line names partition <num> as UUID=<uuid> (quotes
# allowed), has the mount point <mnt> (swap: none or swap), the type
# <type> and the option nofail
fstab_ok() {
	local num=$1 mnt=$2 type=$3 uuid
	image_attached || return 1
	uuid=$(blkid -p -o value -s UUID "$(part "$num")" 2>/dev/null)
	[ -n "$uuid" ] || return 1
	awk -v u="$uuid" -v mnt="$mnt" -v type="$type" '
		/^[[:space:]]*#/ { next }
		{
			src = $1
			gsub(/"/, "", src)
			if (src != "UUID=" u || $3 != type) next
			if (type == "swap") {
				if ($2 != "none" && $2 != "swap") next
			} else if ($2 != mnt) next
			k = split($4, o, ",")
			for (i = 1; i <= k; i++) if (o[i] == "nofail") found = 1
		}
		END { exit !found }' /etc/fstab
}

criterion "$IMG is attached to a loop device" image_attached
criterion "The loop device has a GPT partition table" gpt_label
criterion "The loop device has exactly three partitions" three_partitions
criterion "Partition 1 is 300 MiB and holds XFS" part_ok 1 300 xfs
criterion "Partition 2 is 128 MiB and holds a swap area" part_ok 2 128 swap
criterion "Partition 3 is 100 MiB and holds vfat" part_ok 3 100 vfat
criterion "The XFS file system has the label ARCHIVE" xfs_label
criterion "Partition 1 is mounted on /mnt/archive" mounted_from /mnt/archive 1
criterion "Partition 3 is mounted on /mnt/exchange" mounted_from /mnt/exchange 3
criterion "The swap area on partition 2 is active" swap_active
criterion "fstab mounts partition 1 by UUID on /mnt/archive, nofail" fstab_ok 1 /mnt/archive xfs
criterion "fstab has partition 2 by UUID as swap, nofail" fstab_ok 2 none swap
criterion "fstab mounts partition 3 by UUID on /mnt/exchange, nofail" fstab_ok 3 /mnt/exchange vfat
criterion "/etc/fstab verifies without errors" findmnt --verify
grade_end
