#!/bin/bash
# Reference solution for files-01, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: path /tmp/data
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Steps 1 and 2 [user]
run_as_student <<'STEPS'
mkdir -p /tmp/data
echo "hello" > /tmp/data/info.txt
STEPS
