#!/bin/bash
# Helpers for labs/<lab>/solve.sh (lab framework 2.0).
#
# scripts/test-lab.sh copies this file and the lab's solve.sh into one
# temporary directory on the lab host and runs solve.sh there as root.
# solve.sh sources it with:
#
#   source "$(dirname "$0")/solve-lib.sh"
#
# This file is not shipped in the RPM.

# The normal lab user. test-lab.sh runs the labs as student.
SOLVE_USER="${SOLVE_USER:-student}"

# run_as_student [<script>]
# Run shell code as the normal lab user in a login shell (home directory as
# the working directory, the user's environment), with bash -euo pipefail.
# The code is the first argument, or standard input when no argument is
# given, so a quoted heredoc works:
#
#   run_as_student 'mkdir -p ~/projects'
#   run_as_student <<'EOF'
#   cd /srv/archive
#   touch {a,b}{1,2}
#   EOF
#
# The code is read from standard input by bash, so commands inside it must
# not read standard input themselves.
run_as_student() {
	if [ "$#" -gt 0 ]; then
		printf '%s\n' "$*" | runuser -l "$SOLVE_USER" -c 'bash -euo pipefail -s'
	else
		runuser -l "$SOLVE_USER" -c 'bash -euo pipefail -s'
	fi
}
