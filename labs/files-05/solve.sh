#!/bin/bash
# Reference solution for files-05, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: path /srv/search
# solve: path /home/opsadmin/answers
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Steps 1 to 6 [user]. find exits 1 when it meets an unreadable
# directory, hence the "|| true".
run_as_student <<'STEPS'
find /srv/search -type f -user builder -size +1M 2>/dev/null \
  > ~/answers/large-files.txt || true
find /srv/search/projects -type f -mtime +30 2>/dev/null \
  > ~/answers/old-files.txt || true
find /srv/search -type f -perm -4000 2>/dev/null \
  > ~/answers/setuid.txt || true
{ find /srv/search -type l 2>/dev/null || true; } | wc -l > ~/answers/link-count.txt
grep '^ERROR' /srv/search/logs/app.log | grep -w disk \
  > ~/answers/errors.txt
find /srv/search -name report.txt \
  > ~/answers/report-files.txt 2> ~/answers/denied.txt || true
STEPS
