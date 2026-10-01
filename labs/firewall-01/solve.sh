#!/bin/bash
# Reference solution for firewall-01, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: none
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Step 1 [sudo]
systemctl start firewalld
# Steps 2 to 4 [sudo]
firewall-cmd --zone=public --add-service=http
firewall-cmd --zone=public --add-port=8080/tcp
firewall-cmd --zone=public --list-all >/dev/null
