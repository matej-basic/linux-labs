#!/bin/bash
# storage-01 grader
source /opt/linux-labs/lib/grading.sh

IMG=/srv/disk.img
MNT=/mnt/data

# Size is graded as 95 to 105 MiB (apparent size, so sparse files count)
image_size_ok() {
	local size
	size=$(stat -c %s "$IMG" 2>/dev/null) || return 1
	[ "$size" -ge $((95 * 1048576)) ] && [ "$size" -le $((105 * 1048576)) ]
}

image_is_ext4() {
	[ "$(blkid -o value -s TYPE "$IMG" 2>/dev/null)" = ext4 ]
}

# $MNT is a mount point whose source is a loop device backed by $IMG
mounted_from_image() {
	local src
	mountpoint -q "$MNT" || return 1
	src=$(findmnt -n -o SOURCE --target "$MNT" 2>/dev/null) || return 1
	losetup -j "$IMG" 2>/dev/null | cut -d: -f1 | grep -qx "$src"
}

mounted_as_ext4() {
	mounted_from_image || return 1
	[ "$(findmnt -n -o FSTYPE --target "$MNT" 2>/dev/null)" = ext4 ]
}

mount_root_mode_755() {
	mounted_from_image || return 1
	[ "$(stat -c %a "$MNT" 2>/dev/null)" = 755 ]
}

# Active fstab line: image path, /mnt/data, ext4
fstab_entry() {
	awk -v img="$IMG" -v mnt="$MNT" '
		/^[[:space:]]*#/ { next }
		$1 == img && $2 == mnt && $3 == "ext4" { found = 1 }
		END { exit !found }' /etc/fstab
}

fstab_nofail() {
	awk -v img="$IMG" -v mnt="$MNT" '
		/^[[:space:]]*#/ { next }
		$1 == img && $2 == mnt && $3 == "ext4" {
			n = split($4, o, ",")
			for (i = 1; i <= n; i++) if (o[i] == "nofail") found = 1
		}
		END { exit !found }' /etc/fstab
}

grade_begin storage-01
criterion "File $IMG exists" test -f "$IMG"
criterion "File $IMG is 100 MiB" image_size_ok
criterion "File $IMG contains an ext4 filesystem" image_is_ext4
criterion "Directory $MNT exists" test -d "$MNT"
criterion "$MNT is mounted from a loop device backed by $IMG" mounted_from_image
criterion "$MNT shows an ext4 filesystem" mounted_as_ext4
criterion "Root of the mounted filesystem has mode 755" mount_root_mode_755
criterion "fstab mounts $IMG on $MNT as ext4" fstab_entry
criterion "That fstab entry has the option nofail" fstab_nofail
grade_end
