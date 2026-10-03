#!/bin/bash
# Reference solution for scheduling-04, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: none
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Step 1 [sudo]
systemctl enable --now atd

# Step 2 [user]
run_as_student <<'STEPS'
echo "df -h > $HOME/disk-report.txt" | at 23:30 Dec 31
atq
at -c "$(atq | awk '{ print $1 }' | tail -n 1)" | tail -n 3
STEPS

# Step 3 [sudo]
printf '%s\n' root "$SOLVE_USER" reporter > /etc/at.allow
if runuser -u intern -- at -l </dev/null; then
	echo "intern can still use at" >&2
	exit 1
fi

# Step 4 [user]
run_as_student <<'STEPS'
echo 'umask 027' >> ~/.bashrc
bash -l -c umask
STEPS
