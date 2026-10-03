#!/bin/bash
# Reference solution for packages-08, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: package nodejs
# solve: package npm
# solve: package nodejs-libs
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Step 1 [user]: stream 20 with its common profile
run_as_student <<'STEPS'
dnf module list nodejs </dev/null | grep -E '^nodejs +20 \[e\].*\[i\]' >/dev/null
node --version | grep '^v20\.' >/dev/null
rpm -qa --qf '%{NAME} %{MODULARITYLABEL}\n' | grep ' nodejs:20:' >/dev/null
STEPS

# Step 2 [sudo]
dnf -y module reset nodejs </dev/null
dnf -y module enable nodejs:22 </dev/null

# Step 3 [sudo]
dnf -y distro-sync 'nodejs*' npm </dev/null

# Step 4 [sudo]
dnf -y module install nodejs:22/common </dev/null

# Step 5 [user]
run_as_student <<'STEPS'
dnf module list nodejs </dev/null | grep -E '^nodejs +22 \[e\]' >/dev/null
node --version | grep '^v22\.' >/dev/null
if rpm -qa --qf '%{NAME} %{MODULARITYLABEL}\n' | grep ' nodejs:20:'; then
	exit 1
fi
STEPS
