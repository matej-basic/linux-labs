#!/bin/bash
# storage-10 grader
source /opt/linux-labs/lib/grading.sh

STATE_FILE=/opt/linux-labs/state/storage-10
MNT=/mnt/raid
TEST_FILE=$MNT/before.txt
CONTENT="Written before the disk failure"

grade_begin storage-10
grade_require_state storage-10 "$STATE_FILE"

# The loop device of each image right now (the student may have
# attached it again under another name), else the line of the state file
lab_loop() {
	local d
	d=$(losetup -j "/srv/storage-10-disk$1.img" -O NAME -n 2>/dev/null | head -n 1)
	[ -n "$d" ] || d=$(sed -n "${1}p" "$STATE_FILE")
	echo "${d#/dev/}"
}
l1=$(lab_loop 1)
l2=$(lab_loop 2)
l3=$(lab_loop 3)

# The md array whose name is labraid, with or without the host prefix
md=""
if command -v mdadm >/dev/null 2>&1; then
	for d in /sys/block/md*; do
		[ -e "$d/md" ] || continue
		name=$(mdadm --detail --export "/dev/${d##*/}" 2>/dev/null |
			sed -n 's/^MD_NAME=//p')
		case "$name" in
			labraid | *:labraid)
				md=${d##*/}
				break ;;
		esac
	done
fi
sys=/sys/block/$md/md

array_exists() {
	[ -n "$md" ]
}

raid1_v12() {
	array_exists || return 1
	[ "$(cat "$sys/level" 2>/dev/null)" = raid1 ] &&
		[ "$(cat "$sys/metadata_version" 2>/dev/null)" = 1.2 ]
}

# Two devices in the array, both in sync, nothing degraded or failed
healthy() {
	local state
	array_exists || return 1
	state=$(cat "$sys/array_state" 2>/dev/null)
	case "$state" in
		clean | active | active-idle) ;;
		*) return 1 ;;
	esac
	[ "$(cat "$sys/raid_disks" 2>/dev/null)" = 2 ] &&
		[ "$(cat "$sys/degraded" 2>/dev/null)" = 0 ] &&
		! grep -qs faulty "$sys"/dev-*/state
}

idle() {
	array_exists || return 1
	[ "$(cat "$sys/sync_action" 2>/dev/null)" = idle ]
}

# <loop> is a member whose state contains <word> (in_sync or spare)
member_is() {
	local st
	array_exists && [ -n "$1" ] || return 1
	st=$(cat "$sys/dev-$1/state" 2>/dev/null) || return 1
	case ",$st," in
		*,faulty,*) return 1 ;;
		*",$2,"*) ;;
		*) return 1 ;;
	esac
	if [ "$2" = spare ]; then
		[ "$(cat "$sys/dev-$1/slot" 2>/dev/null)" = none ]
	fi
}

actives_ok() {
	member_is "$l1" in_sync && member_is "$l3" in_sync
}

# Exactly the three lab loop devices are members
only_lab_members() {
	local d n=0
	array_exists || return 1
	for d in "$sys"/dev-*; do
		[ -e "$d" ] || continue
		case "${d##*/dev-}" in
			"$l1" | "$l2" | "$l3") n=$((n + 1)) ;;
			*) return 1 ;;
		esac
	done
	[ "$n" -eq 3 ]
}

xfs_label() {
	array_exists || return 1
	[ "$(blkid -p -o value -s TYPE "/dev/$md" 2>/dev/null)" = xfs ] &&
		[ "$(blkid -p -o value -s LABEL "/dev/$md" 2>/dev/null)" = RAIDDATA ]
}

mounted_from_array() {
	local src
	array_exists || return 1
	src=$(findmnt -rn -M "$MNT" -o SOURCE 2>/dev/null | tail -n 1)
	[ -n "$src" ] && [ "$(readlink -f "$src")" = "/dev/$md" ]
}

test_file_ok() {
	mounted_from_array || return 1
	[ -f "$TEST_FILE" ] && [ "$(cat "$TEST_FILE" 2>/dev/null)" = "$CONTENT" ]
}

# An active ARRAY line in /etc/mdadm.conf carries the UUID of the array
mdadm_conf_ok() {
	local uuid
	array_exists || return 1
	uuid=$(mdadm --detail --export "/dev/$md" 2>/dev/null |
		sed -n 's/^MD_UUID=//p')
	[ -n "$uuid" ] && [ -f /etc/mdadm.conf ] || return 1
	awk -v u="$uuid" '
		/^ARRAY[[:space:]]/ { inarray = 1 }
		/^[^[:space:]]/ && !/^ARRAY[[:space:]]/ { inarray = 0 }
		inarray {
			n = split($0, f, /[[:space:]]+/)
			for (i = 1; i <= n; i++)
				if (toupper(f[i]) == toupper("UUID=" u)) found = 1
		}
		END { exit !found }' /etc/mdadm.conf
}

# An active fstab line: UUID=<uuid of the XFS> (quotes allowed), the
# mount point, xfs and the option nofail
fstab_ok() {
	local uuid
	array_exists || return 1
	uuid=$(blkid -p -o value -s UUID "/dev/$md" 2>/dev/null)
	[ -n "$uuid" ] || return 1
	awk -v u="$uuid" -v mnt="$MNT" '
		/^[[:space:]]*#/ { next }
		{
			src = $1
			gsub(/"/, "", src)
			if (toupper(src) != toupper("UUID=" u)) next
			if ($2 != mnt || $3 != "xfs") next
			k = split($4, o, ",")
			for (i = 1; i <= k; i++) if (o[i] == "nofail") found = 1
		}
		END { exit !found }' /etc/fstab
}

criterion "An md array named labraid exists" array_exists
criterion "labraid is RAID 1 with metadata 1.2" raid1_v12
criterion "labraid has 2 devices in sync and is not degraded" healthy
criterion "No resync or recovery is running on labraid" idle
criterion "The devices from lines 1 and 3 are the active members" actives_ok
criterion "The device from line 2 is the hot spare of labraid" member_is "$l2" spare
criterion "Only the three lab loop devices are members of labraid" only_lab_members
criterion "labraid holds XFS with the label RAIDDATA" xfs_label
criterion "labraid is mounted on $MNT" mounted_from_array
criterion "$TEST_FILE has the required content" test_file_ok
criterion "/etc/mdadm.conf has an ARRAY line with the UUID of labraid" mdadm_conf_ok
criterion "fstab mounts the XFS by UUID on $MNT, nofail" fstab_ok
criterion "/etc/fstab verifies without errors" findmnt --verify
grade_end
