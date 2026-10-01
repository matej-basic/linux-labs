#!/bin/bash
# storage-03 cleanup: removes the snapshot, LV, VG, PV, loop device, image,
# mount points and fstab entries. Only snapvg and the loop devices backing
# /tmp/snap.img are touched; the rl volume group and real disks never are.
IMG=/tmp/snap.img

# Loop devices to release: the ones backing the image and the PVs of snapvg
loops=""
if [ -e "$IMG" ]; then
	loops=$(losetup -j "$IMG" 2>/dev/null | cut -d: -f1)
fi
if vgs --noheadings snapvg >/dev/null 2>&1; then
	pvloops=$(pvs --noheadings -o pv_name -S vg_name=snapvg 2>/dev/null | awk '/^ *\/dev\/loop/ { print $1 }')
	loops="$loops $pvloops"
fi

# Remove lab entries from fstab before unmounting
if grep -qE '(/mnt/original|/mnt/snap1|snapvg)' /etc/fstab 2>/dev/null; then
	sed -i -E '\#(/mnt/original|/mnt/snap1|snapvg)#d' /etc/fstab
	systemctl daemon-reload >/dev/null 2>&1 || true
fi

# Unmount
for m in /mnt/snap1 /mnt/original; do
	if mountpoint -q "$m" 2>/dev/null; then
		umount "$m" 2>/dev/null || umount -l "$m" 2>/dev/null || true
	fi
done

# LVM objects of the lab (snapshot goes with the VG)
if vgs --noheadings snapvg >/dev/null 2>&1; then
	vgchange -an snapvg >/dev/null 2>&1 || true
	lvremove -f snapvg >/dev/null 2>&1 || true
	vgremove -f snapvg >/dev/null 2>&1 || true
fi

# shellcheck disable=SC2086 # word splitting of the device list is intended
for dev in $(printf '%s\n' $loops | sort -u); do
	if [ -b "$dev" ]; then
		pvremove -ff -y "$dev" >/dev/null 2>&1 || true
		if command -v lvmdevices >/dev/null 2>&1; then
			lvmdevices --deldev "$dev" >/dev/null 2>&1 || true
		fi
		losetup -d "$dev" 2>/dev/null || true
	fi
done

rm -f "$IMG"
rmdir /mnt/snap1 /mnt/original 2>/dev/null || true
rm -rf /opt/linux-labs/state/storage-03
exit 0
