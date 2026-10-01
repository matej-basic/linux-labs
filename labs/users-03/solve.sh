#!/bin/bash
# Reference solution for users-03, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: path /srv/shared
# solve: path /home/bob
# solve: path /home/charlie
set -euo pipefail
# shellcheck source=/dev/null
source "$(dirname "$0")/solve-lib.sh"

# Step 1 [sudo]
groupadd -g 2000 devops
groupadd -g 2001 analytics

# Step 2 [sudo]
useradd -u 1010 -m -g devops -G wheel,analytics -s /bin/bash bob
chmod 750 /home/bob

# Step 3 [sudo]
useradd -u 1011 -m -g analytics -G wheel -s /bin/bash charlie
chmod 750 /home/charlie
chage -E 2099-12-31 charlie

# Step 4 [sudo]
mkdir -p /srv/shared/analytics
chown root:devops /srv/shared
chmod 750 /srv/shared
setfacl -d -m g:devops:rwx /srv/shared

# Step 5 [sudo]
chown root:analytics /srv/shared/analytics
chmod 750 /srv/shared/analytics
setfacl -m u:charlie:rwx /srv/shared/analytics

# Step 6 [sudo]
setfacl -m u:charlie:x /srv/shared
