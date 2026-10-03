#!/bin/bash
# Reference solution for storage-08, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: path /srv/storage-08.img
# solve: path /srv/projects
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Step 1 [sudo]
mkfs.xfs -q /srv/storage-08.img

# Step 2 [sudo]
mkdir -p /srv/projects
OPTS=loop,usrquota,grpquota,nofail
echo "/srv/storage-08.img /srv/projects xfs $OPTS 0 0" >> /etc/fstab
systemctl daemon-reload
mount /srv/projects

# Step 3 [sudo]
xfs_quota -x -c state /srv/projects

# Step 4 [sudo]
xfs_quota -x \
	-c 'limit -u bsoft=80m bhard=100m ihard=1000 qalice' /srv/projects
xfs_quota -x -c 'limit -u bhard=50m qbob' /srv/projects
xfs_quota -x -c 'limit -g bhard=200m qteam' /srv/projects

# Step 5 [sudo]
mkdir /srv/projects/team
chgrp qteam /srv/projects/team
chmod 2770 /srv/projects/team

# Verification
findmnt --verify
