#!/bin/bash
# Reference solution for files-08, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: path /srv/textlab
# solve: path /home/opsadmin/reports
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Steps 1 to 6 [user]
run_as_student <<'STEPS'
mkdir -p ~/reports
cd /srv/textlab
cut -d ' ' -f 1 access.log | sort | uniq -c | sort -rn |
  head -n 5 | awk '{ print $1, $2 }' > ~/reports/top-ips.txt
awk '$9 == 404' access.log | wc -l > ~/reports/not-found.txt
awk '{ print $7 }' access.log | LC_ALL=C sort -u \
  > ~/reports/paths.txt
awk '$10 != "-" { sum += $10 } END { print sum }' access.log \
  > ~/reports/bytes.txt
tail -n +2 accounts.csv |
  awk -F, '$4 == "/bin/bash" { print $1 ":" $2 }' |
  sort -t : -k 2,2n > ~/reports/bash-users.txt
STEPS
