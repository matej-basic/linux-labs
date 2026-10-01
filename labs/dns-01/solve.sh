#!/bin/bash
# Reference solution for dns-01, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: package bind
# solve: package bind-utils
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Step 1 [sudo]
dnf -y install bind bind-utils

# Step 2 and 3 [sudo]
systemctl enable --now named

# Step 4 [sudo]: wait until named has bound port 53
for _ in $(seq 1 15); do
	[ -n "$(ss -H -ltn 'sport = :53')" ] && break
	sleep 1
done
