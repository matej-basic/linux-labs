#!/bin/bash
# storage-02 grader
source /opt/linux-labs/lib/grading.sh

IMG=/tmp/lvm.img
VG=datavg
LV=vol0
MNT=/mnt/lvm

grade_begin storage-02
grade_require_state storage-02

img_loops() {
	losetup -j "$IMG" -O NAME -n 2>/dev/null
}

image_size_ok() {
	local size
	[ -f "$IMG" ] && [ ! -L "$IMG" ] || return 1
	size=$(stat -c %s "$IMG")
	[ "$size" -ge 100000000 ] && [ "$size" -le 104857600 ]
}

loop_attached() {
	[ -n "$(img_loops)" ]
}

pv_on_loop() {
	local d
	for d in $(img_loops); do
		pvs --noheadings "$d" >/dev/null 2>&1 && return 0
	done
	return 1
}

pv_in_vg() {
	local d
	for d in $(img_loops); do
		[ "$(pvs --noheadings -o vg_name "$d" 2>/dev/null | tr -d ' ')" = "$VG" ] && return 0
	done
	return 1
}

lv_size_ok() {
	local size
	size=$(lvs --noheadings --nosuffix --units b -o lv_size "$VG/$LV" 2>/dev/null | tr -d ' ')
	[ -n "$size" ] && [ "$size" -ge 80000000 ]
}

lv_is_ext4() {
	[ "$(blkid -p -o value -s TYPE "/dev/$VG/$LV" 2>/dev/null)" = ext4 ]
}

lv_mounted() {
	local src
	src=$(findmnt -rn -M "$MNT" -o SOURCE 2>/dev/null | tail -n 1)
	[ -n "$src" ] && [ "$(readlink -f "$src")" = "$(readlink -f "/dev/$VG/$LV")" ]
}

mount_mode_755() {
	lv_mounted && [ "$(stat -c %a "$MNT" 2>/dev/null)" = 755 ]
}

criterion "File $IMG is a 100 MB disk image" image_size_ok
criterion "$IMG is attached to a loop device" loop_attached
criterion "The loop device is an LVM physical volume" pv_on_loop
criterion "Volume group $VG contains that physical volume" pv_in_vg
criterion "Logical volume $LV exists in $VG" lvs "$VG/$LV"
criterion "Logical volume $LV is at least 80 MB" lv_size_ok
criterion "Logical volume $LV holds an ext4 file system" lv_is_ext4
criterion "Directory $MNT exists" test -d "$MNT"
criterion "Logical volume $LV is mounted on $MNT" lv_mounted
criterion "Mounted file system root $MNT has mode 755" mount_mode_755
grade_end
