#!/bin/bash
# Reference solution for systemd-06, the same steps as solution.md.
# Run as root by scripts/test-lab.sh; not shipped in the RPM.
#
# solve: path /usr/local/bin/lab-report
# solve: path /usr/local/bin/lab-ingest
# solve: path /usr/local/bin/lab-stale
# solve: path /usr/local/bin/lab-hung
# solve: path /usr/local/bin/lab-batch
set -euo pipefail
source "$(dirname "$0")/solve-lib.sh"

# Step 1 [user]
run_as_student 'ps -o pid,user,ni,comm -C lab-report,lab-ingest,lab-stale,lab-hung'

# Steps 2 and 3 [sudo]
renice -n 15 -p "$(pgrep -x lab-report)" >/dev/null
renice -n -5 -p "$(pgrep -x lab-ingest)" >/dev/null

# Step 4 [sudo]
kill -TERM "$(pgrep -x lab-stale)"

# Step 5 [sudo]: SIGTERM is ignored, SIGKILL ends it
kill -TERM "$(pgrep -x lab-hung)"
sleep 1
pgrep -x lab-hung >/dev/null
kill -KILL "$(pgrep -x lab-hung)"

# Step 6 [user]: the login shell of run_as_student ends right after this,
# like the logout in solution.md
run_as_student 'nohup nice -n 10 /usr/local/bin/lab-batch >/dev/null 2>&1 &'

# Give the signals and the new job a moment before grading
for _ in $(seq 1 20); do
	if ! pgrep -x lab-stale >/dev/null && ! pgrep -x lab-hung >/dev/null &&
		pgrep -x lab-batch >/dev/null; then
		exit 0
	fi
	sleep 0.25
done
echo "solve: the processes did not reach the end state" >&2
exit 1
