#!/bin/bash
# storage-02 cleanup: unmounts and removes the lab's LV/VG/PV, the loop
# devices, the image, the fstab entries and the state file. Only volume
# groups whose physical volumes are all loop devices are removed, so
# the real disks and the rl volume group are never touched.
IMG=/tmp/lvm.img
MNT=/mnt/lvm

# Remove fstab entries of the lab, whatever options they carry
if grep -qE '(/dev/datavg/|/dev/mapper/datavg-|[[:space:]]/mnt/lvm([[:space:]]|$))' /etc/fstab 2>/dev/null; then
	sed -i -E '\#(/dev/datavg/|/dev/mapper/datavg-|[[:space:]]/mnt/lvm([[:space:]]|$))#d' /etc/fstab
	systemctl daemon-reload >/dev/null 2>&1
fi

# Unmount everything mounted from a datavg volume (nested mounts first)
findmnt -rn -o SOURCE,TARGET 2>/dev/null |
	awk '$1 ~ /^\/dev\/(mapper\/datavg-|datavg\/)/ { print $2 }' |
	sort -r | while read -r t; do
		umount "$t" >/dev/null 2>&1 || umount -l "$t" >/dev/null 2>&1
	done

# Loop devices backed by the lab image
loops=$(losetup -j "$IMG" -O NAME -n 2>/dev/null)

# Volume groups to remove: datavg, and any VG on the image's loop devices
vgs_found=datavg
for d in $loops; do
	v=$(pvs --noheadings -o vg_name "$d" 2>/dev/null | tr -d ' ')
	[ -n "$v" ] && vgs_found="$vgs_found $v"
done

for v in $(echo "$vgs_found" | tr ' ' '\n' | sort -u); do
	vgs --noheadings "$v" >/dev/null 2>&1 || continue
	pvlist=$(pvs --noheadings -o pv_name -S "vg_name=$v" 2>/dev/null | awk '{ print $1 }')
	# Skip a VG with no PVs listed or with any PV that is not a loop device
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

# Plain PVs on the image's loop devices (no VG), then detach the loops
for d in $loops; do
	[ -b "$d" ] || continue
	pvs --noheadings "$d" >/dev/null 2>&1 && pvremove -ff -y "$d" >/dev/null 2>&1
	command -v lvmdevices >/dev/null 2>&1 && lvmdevices --deldev "$d" >/dev/null 2>&1
	losetup -d "$d" >/dev/null 2>&1
done

rm -f "$IMG"
rmdir "$MNT" 2>/dev/null
rm -f /opt/linux-labs/state/storage-02
exit 0
