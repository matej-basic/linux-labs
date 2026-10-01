#!/bin/bash
# Reference solution for files-03, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: path /srv/secure
# solve: path /tmp/backup.tar.gz
# solve: path /home/alice
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Step 1 [sudo]
groupadd -g 3000 developers
useradd -u 1001 alice

# Step 2 [sudo]
mkdir -p /srv/secure/bin /srv/secure/shared /srv/secure/tmp
chown root:root /srv/secure
chmod 755 /srv/secure
echo 'echo "Deployment tool"' > /srv/secure/bin/deploy.sh
chown root:root /srv/secure/bin/deploy.sh
chmod 4755 /srv/secure/bin/deploy.sh

# Step 3 [sudo]
chown root:developers /srv/secure/shared
chmod 2770 /srv/secure/shared
setfacl -m g:developers:rwx /srv/secure/shared

# Step 4 [sudo]
chown root:root /srv/secure/tmp
chmod 1777 /srv/secure/tmp
setfacl -m u:alice:rwx /srv/secure/tmp

# Step 5 [sudo]
tar -czpf /tmp/backup.tar.gz /srv/secure
