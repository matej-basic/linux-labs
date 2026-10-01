#!/bin/bash
# Reference solution for selinux-01, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: none
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Step 1 [sudo]
setenforce 1
getenforce

# Step 2 [sudo]
sed -i -E 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config
grep '^SELINUX' /etc/selinux/config

# Step 3 [user]
run_as_student 'sestatus'
