#!/bin/bash
# Reference solution for storage-06, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: path /srv/storage-06.img
# solve: path /mnt/archive
# solve: path /mnt/exchange
# solve: package dosfstools
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Step 1 [user]
LOOP=$(head -n 1 /opt/linux-labs/state/storage-06)
run_as_student "lsblk $LOOP"

# Step 2 [sudo]
parted -s "$LOOP" mklabel gpt \
	mkpart archive xfs 1MiB 301MiB \
	mkpart swap linux-swap 301MiB 429MiB \
	mkpart exchange fat32 429MiB 529MiB
udevadm settle

# Step 3 [sudo]
rpm -q dosfstools >/dev/null || dnf -y install dosfstools >/dev/null

# Step 4 [sudo]
mkfs.xfs -L ARCHIVE "${LOOP}p1"
mkswap "${LOOP}p2"
mkfs.vfat "${LOOP}p3"

# Step 5 [sudo]
U1=$(blkid -p -o value -s UUID "${LOOP}p1")
U2=$(blkid -p -o value -s UUID "${LOOP}p2")
U3=$(blkid -p -o value -s UUID "${LOOP}p3")
{
	echo "UUID=$U1 /mnt/archive xfs defaults,nofail 0 0"
	echo "UUID=$U2 none swap defaults,nofail 0 0"
	echo "UUID=$U3 /mnt/exchange vfat defaults,nofail 0 0"
} >> /etc/fstab
systemctl daemon-reload

# Step 6 [sudo]
mkdir -p /mnt/archive /mnt/exchange
mount /mnt/archive
mount /mnt/exchange
swapon -a

# Verification
findmnt --verify
