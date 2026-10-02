#!/bin/bash
# Reference solution for webserver-01, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: none
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Step 1 [sudo]
dnf -y install httpd >/dev/null

# Step 2 [sudo]
systemctl enable --now httpd

# Step 3 [user]
for _ in 1 2 3 4 5; do
	run_as_student 'curl -sI http://localhost >/dev/null' && break
	sleep 1
done
