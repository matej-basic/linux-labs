#!/bin/bash
# Reference solution for packages-01, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: package git
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Step 1 [user]
run_as_student <<'STEPS'
dnf search git > /dev/null
STEPS

# Step 2 [sudo]
rpm -q git >/dev/null || dnf -y install git

# Step 3 [user]
run_as_student <<'STEPS'
rpm -q git
command -v git
git --version
STEPS
