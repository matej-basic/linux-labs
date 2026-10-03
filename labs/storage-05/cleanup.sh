#!/bin/bash
# storage-05 cleanup: unmounts the lab file systems, removes growvg with
# its logical and physical volumes, the LVM devices file entries of the
# images (EL9), the loop devices, the images, the mount points, any fstab
# entries of the lab and the state file. Only volume groups whose
# physical volumes are all loop devices are removed, so the volume group
# of the operating system is never touched.
DIR=/srv/growvg
VG=growvg
IMGS="$DIR/disk1.img $DIR/disk2.img"
DEVFILE=/etc/lvm/devices/system.devices

# fstab entries of the lab, whatever options they carry
if grep -qE '(/dev/growvg/|/dev/mapper/growvg-|[[:space:]]/mnt/(xfsdata|extdata)([[:space:]]|$))' /etc/fstab 2>/dev/null; then
	sed -i -E '\#(/dev/growvg/|/dev/mapper/growvg-|[[:space:]]/mnt/(xfsdata|extdata)([[:space:]]|$))#d' /etc/fstab
	systemctl daemon-reload >/dev/null 2>&1
fi

# Unmount everything mounted from a growvg volume or on the lab mount points
findmnt -rn -o SOURCE,TARGET 2>/dev/null |
	awk '$1 ~ /^\/dev\/(mapper\/growvg-|growvg\/)/ || $2 ~ /^\/mnt\/(xfsdata|extdata)$/ { print $2 }' |
	sort -ru | while read -r t; do
		umount "$t" >/dev/null 2>&1 || umount -l "$t" >/dev/null 2>&1
	done

# Loop devices backed by the lab images
loops=""
for img in $IMGS; do
	[ -e "$img" ] || continue
	loops="$loops $(losetup -j "$img" -O NAME -n 2>/dev/null)"
done

# Volume groups to remove: growvg, and any VG on the images' loop devices
vgs_found=$VG
for d in $loops; do
	v=$(pvs --noheadings -o vg_name "$d" 2>/dev/null | tr -d ' ')
	[ -n "$v" ] && vgs_found="$vgs_found $v"
done

for v in $(echo "$vgs_found" | tr ' ' '\n' | sort -u); do
	vgs --noheadings "$v" >/dev/null 2>&1 || continue
	pvlist=$(pvs --noheadings -o pv_name -S "vg_name=$v" 2>/dev/null | awk '{ print $1 }')
	[ -n "$pvlist" ] || continue
	echo "$pvlist" | grep -qv '^/dev/loop' && continue
	vgchange -an "$v" >/dev/null 2>&1
	vgremove -ff -y "$v" >/dev/null 2>&1
	for p in $pvlist; do
		pvremove -ff -y "$p" >/dev/null 2>&1
		loops="$loops $p"
	done
	dmsetup ls 2>/dev/null | awk -v p="^$v-" '$1 ~ p { print $1 }' |
		while read -r m; do dmsetup remove -f "$m" >/dev/null 2>&1; done
done

# Plain PVs on the loop devices, devices file entries, then detach
for d in $(echo "$loops" | tr ' ' '\n' | sort -u); do
	[ -b "$d" ] || continue
	pvs --noheadings "$d" >/dev/null 2>&1 && pvremove -ff -y "$d" >/dev/null 2>&1
	command -v lvmdevices >/dev/null 2>&1 && lvmdevices --deldev "$d" >/dev/null 2>&1
	losetup -d "$d" >/dev/null 2>&1
done

# Stale devices file entries of the images (loop device gone, for
# example after a reboot)
if [ -f "$DEVFILE" ] && command -v lvmdevices >/dev/null 2>&1; then
	grep -E "IDNAME=$DIR/disk[12]\.img( |$)" "$DEVFILE" 2>/dev/null |
		sed -n 's/.*PVID=\([^ ]*\).*/\1/p' | while read -r id; do
			lvmdevices --delpvid "$id" >/dev/null 2>&1
		done
fi

rm -f "$DIR/disk1.img" "$DIR/disk2.img"
rmdir "$DIR" 2>/dev/null
rmdir /mnt/xfsdata /mnt/extdata 2>/dev/null
rm -f /opt/linux-labs/state/storage-05
exit 0
