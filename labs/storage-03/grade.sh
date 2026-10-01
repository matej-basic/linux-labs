#!/bin/bash
# storage-03 grader
source /opt/linux-labs/lib/grading.sh

IMG=/tmp/snap.img
VG=snapvg

grade_begin storage-03

# Size of an LV in bytes
lv_bytes() {
	lvs --noheadings --nosuffix --units b -o lv_size "$VG/$1" 2>/dev/null | tr -d ' '
}

image_big_enough() {
	[ -f "$IMG" ] && [ "$(stat -c %s "$IMG")" -ge 157286400 ]
}

# Every PV of the VG is a loop device that backs the image, and there is one
vg_on_image_loop() {
	local pvs pv n=0
	pvs=$(pvs --noheadings -o pv_name -S "vg_name=$VG" 2>/dev/null | tr -d ' ')
	[ -n "$pvs" ] || return 1
	for pv in $pvs; do
		losetup -j "$IMG" 2>/dev/null | cut -d: -f1 | grep -qx "$pv" || return 1
		n=$((n + 1))
	done
	[ "$n" -eq 1 ]
}

lv_size_is() {
	[ "$(lv_bytes "$1")" = "$2" ]
}

lv_size_at_least() {
	local b
	b=$(lv_bytes "$1")
	[ -n "$b" ] && [ "$b" -ge "$2" ]
}

# Mount point is mounted from the given LV
mounted_from() {
	[ "$(findmnt -n -o SOURCE "$1" 2>/dev/null)" = "/dev/mapper/$VG-$2" ]
}

mount_fstype_is() {
	[ "$(findmnt -n -o FSTYPE "$1" 2>/dev/null)" = "$2" ]
}

snap_of_original() {
	[ "$(lvs --noheadings -o origin "$VG/snap1" 2>/dev/null | tr -d ' ')" = "original" ]
}

snap_active_valid() {
	local attr
	attr=$(lvs --noheadings -o lv_attr "$VG/snap1" 2>/dev/null | tr -d ' ')
	[ "${attr:0:1}" = "s" ] && [ "${attr:4:1}" = "a" ]
}

file_is_line() {
	[ -f "$1" ] && [ "$(cat "$1")" = "$2" ]
}

before_in_both() {
	file_is_line /mnt/original/before.txt "before snapshot" &&
		file_is_line /mnt/snap1/before.txt "before snapshot"
}

after_only_in_original() {
	file_is_line /mnt/original/testfile.txt "after snapshot" &&
		[ ! -e /mnt/snap1/testfile.txt ]
}

criterion "File $IMG is at least 150 MiB" image_big_enough
criterion "Volume group $VG exists on one loop device backed by the image" vg_on_image_loop
criterion "Logical volume original is 100 MiB" lv_size_is original 104857600
criterion "original is mounted on /mnt/original" mounted_from /mnt/original original
criterion "/mnt/original holds an ext4 file system" mount_fstype_is /mnt/original ext4
criterion "snap1 is a snapshot of original" snap_of_original
criterion "snap1 is at least 20 MiB" lv_size_at_least snap1 20971520
criterion "snap1 is active and not invalid" snap_active_valid
criterion "snap1 is mounted on /mnt/snap1" mounted_from /mnt/snap1 snap1
criterion "before.txt is in /mnt/original and /mnt/snap1" before_in_both
criterion "testfile.txt is only in /mnt/original, not in snap1" after_only_in_original
grade_end
