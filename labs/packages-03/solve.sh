#!/bin/bash
# Reference solution for packages-03, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: path /tmp/curl-files.txt
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Step 1 [sudo]
dnf -y install curl

# Step 2 [user]
run_as_student <<'STEPS'
rpm -ql curl > /tmp/curl-files.txt
STEPS
