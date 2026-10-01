#!/bin/bash
# Reference solution for files-04, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: path /srv/archive
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Steps 1 to 3 [user]
run_as_student <<'STEPS'
cd /srv/archive
touch {report,memo,chart}_{sep,oct,nov,dec}_{a,b,c}{1,2,3}
mkdir -p {report,memo,chart}/{sep,oct,nov,dec}
for t in report memo chart; do
  for m in sep oct nov dec; do
    mv "${t}_${m}_"* "$t/$m/"
  done
done
STEPS
