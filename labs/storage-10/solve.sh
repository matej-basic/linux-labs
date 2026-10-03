#!/bin/bash
# Reference solution for storage-10, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: path /srv/storage-10-disk1.img
# solve: path /srv/storage-10-disk2.img
# solve: path /srv/storage-10-disk3.img
# solve: path /mnt/raid
# solve: path /etc/mdadm.conf
# solve: path /dev/md/labraid
# solve: package mdadm
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Wait until the array is not degraded and no resync or recovery runs
wait_idle() {
	local sys
	sys=/sys/block/$(basename "$(readlink -f /dev/md/labraid)")/md
	mdadm --wait /dev/md/labraid || true
	for _ in $(seq 1 120); do
		if [ "$(cat "$sys/sync_action")" = idle ] &&
			[ "$(cat "$sys/degraded")" = 0 ]; then
			return 0
		fi
		sleep 1
	done
	echo "the array did not finish its sync" >&2
	return 1
}

# Step 1 [user]
D1=$(sed -n 1p /opt/linux-labs/state/storage-10)
D2=$(sed -n 2p /opt/linux-labs/state/storage-10)
D3=$(sed -n 3p /opt/linux-labs/state/storage-10)
run_as_student "lsblk $D1 $D2 $D3"

# Step 2 [sudo]
rpm -q mdadm >/dev/null || dnf -y install mdadm >/dev/null

# Step 3 [sudo]
mdadm --create /dev/md/labraid --run --level=1 \
	--metadata=1.2 --name=labraid --raid-devices=2 "$D1" "$D2" \
	--spare-devices=1 "$D3"
udevadm settle
wait_idle
cat /proc/mdstat

# Step 4 [sudo]
mkfs.xfs -q -L RAIDDATA /dev/md/labraid
U=$(blkid -p -o value -s UUID /dev/md/labraid)
echo "UUID=$U /mnt/raid xfs defaults,nofail 0 0" >> /etc/fstab
systemctl daemon-reload
mkdir -p /mnt/raid
mount /mnt/raid
echo "Written before the disk failure" > /mnt/raid/before.txt

# Step 5 [sudo]
mdadm --detail --brief /dev/md/labraid >> /etc/mdadm.conf

# Step 6 [sudo]
mdadm /dev/md/labraid --fail "$D2"
mdadm /dev/md/labraid --remove "$D2"
sleep 1
wait_idle
cat /proc/mdstat

# Step 7 [sudo]
mdadm /dev/md/labraid --add "$D2"
mdadm --detail /dev/md/labraid

# Verification
findmnt --verify
