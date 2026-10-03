#!/bin/bash
# Reference solution for users-06, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: path /home/anna
# solve: path /home/ben
# solve: path /home/carla
# solve: path /home/dario
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Step 1 [sudo]
chage -l anna >/dev/null
passwd -S ben >/dev/null
getent passwd carla dario >/dev/null

# Step 2 [sudo]
chage -E -1 anna

# Step 3 [sudo]
usermod -U ben

# Step 4 [sudo]
usermod -s /bin/bash carla

# Step 5 [sudo]
cp -a /etc/skel /home/dario
chown -R dario:dario /home/dario
chmod 0700 /home/dario
restorecon -R /home/dario

# Step 6 [user]
run_as_student <<'STEPS'
for u in anna ben carla dario; do
	printf '%s\n' Harbor-Lantern-58 | su - "$u" -c pwd
done
STEPS
