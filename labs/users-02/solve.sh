#!/bin/bash
# Reference solution for users-02, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: path /home/dave
# solve: path /home/eve
# solve: path /etc/security/limits.d/70-contractors.conf
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Step 1 [sudo]
groupadd contractors

# Step 2 [sudo]
useradd -m -g contractors -s /bin/bash dave
echo 'contractor123' | passwd --stdin dave >/dev/null
chage -M 30 dave

# Step 3 [sudo]
useradd -m -g contractors -s /bin/bash -e 2030-12-31 eve
echo 'eve-pass' | passwd --stdin eve >/dev/null
chage -M -1 eve

# Step 4 [sudo]
tee /etc/security/limits.d/70-contractors.conf >/dev/null <<'LIMITS'
@contractors soft nofile 1024
@contractors hard nofile 1024
@contractors soft nproc 512
@contractors hard nproc 512
LIMITS

# Step 5 [sudo]
sed -i -E 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS   90/; s/^PASS_MIN_DAYS.*/PASS_MIN_DAYS   1/; s/^PASS_WARN_AGE.*/PASS_WARN_AGE   14/' /etc/login.defs
