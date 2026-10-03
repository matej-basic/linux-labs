#!/bin/bash
# Reference solution for storage-11, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: path /srv/storage-11-appdata.img
# solve: path /srv/storage-11-archive.img
# solve: path /srv/appdata
# solve: path /srv/archive
# solve: path /etc/systemd/system/app-logger.service
# solve: path /usr/local/bin/app-logger
# solve: path /opt/linux-labs/state/storage-11.orig
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Step 1 [sudo]
df -h /srv/appdata
du -sh /srv/appdata
du -ah /srv/appdata | sort -h | tail -n 5

# Step 2 [sudo]
ls -la /srv/appdata/.cache
rm -f /srv/appdata/.cache/core.*

# Step 3 [sudo]
find /proc/[0-9]*/fd -lname '/srv/appdata/*(deleted)' \
	-printf '%h %l\n' 2>/dev/null || true
systemctl restart app-logger.service
sleep 1
df -h /srv/appdata

# Step 4 [sudo]
findmnt --verify || true
blkid /srv/storage-11-archive.img

# Step 5 [sudo]
sed -i '/ \/srv\/archive /s/ ext4 / xfs /' /etc/fstab
systemctl daemon-reload
findmnt --verify
mount /srv/archive
ls -lR /srv/archive
