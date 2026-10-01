#!/bin/bash
# Reference solution for packages-02, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: package epel-release
# solve: package htop
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Step 1 [sudo]
dnf -y install epel-release

# Step 2 [user]
run_as_student <<'STEPS'
dnf repolist
dnf info htop
STEPS

# Step 3 [sudo]
dnf -y install htop

# Step 4 [user]
run_as_student <<'STEPS'
rpm -q htop
htop --version
STEPS
