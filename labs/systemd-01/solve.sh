#!/bin/bash
# Reference solution for systemd-01, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: path /etc/systemd/system/test-service.service
# solve: path /etc/systemd/system/multi-user.target.wants/test-service.service
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Step 1 [sudo]
systemctl enable test-service.service
# Step 2 [sudo]
systemctl start test-service.service
