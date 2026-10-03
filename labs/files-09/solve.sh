#!/bin/bash
# Reference solution for files-09, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: path /srv/linklab
# solve: path /home/opsadmin/answers
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Steps 1 to 6 [user]
run_as_student <<'STEPS'
cd /srv/linklab
ln data/report.txt backup/report.txt
ln -s releases/v2 current
ln -sfn /srv/linklab/etc/app.conf app.conf
find /srv/linklab -samefile /srv/linklab/data/shared.dat \
  | sort > ~/answers/inode-names.txt
rm data/old.txt
ln -sfn releases/v2 latest
STEPS
