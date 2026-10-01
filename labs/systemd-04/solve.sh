#!/bin/bash
# Reference solution for systemd-04, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: reboot
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Step 1 [user]
run_as_student 'systemctl get-default >/dev/null'

# Step 2 [sudo]
systemctl set-default multi-user.target >/dev/null 2>&1

# Step 3 [sudo]: the reboot is done by test-lab.sh (solve: reboot)
