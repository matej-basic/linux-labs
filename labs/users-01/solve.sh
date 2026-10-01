#!/bin/bash
# Reference solution for users-01, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: path /home/alice
# solve: path /srv/svcapp
# solve: path /srv/project
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Step 1 [sudo]
groupadd project

# Step 2 [sudo]
useradd -m -g project -G wheel -s /bin/bash alice

# Step 3 [sudo]
useradd -r -M -d /srv/svcapp -g project -s /usr/sbin/nologin svcapp
mkdir -p /srv/svcapp
chown svcapp:project /srv/svcapp
chmod 750 /srv/svcapp

# Step 4 [sudo]
mkdir -p /srv/project
chown root:project /srv/project
chmod 2775 /srv/project
