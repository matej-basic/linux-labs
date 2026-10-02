#!/bin/bash
# Helpers for labs/<lab>/solve.sh (lab framework 2.0).
#
# scripts/test-lab.sh copies this file and the lab's solve.sh into one
# temporary directory on the machine the lab runs on (the workstation, or
# the server named by "target:" in description.txt) and runs solve.sh
# there as root. solve.sh sources it with:
#
#   source "$(dirname "$0")/solve-lib.sh"
#
# This file is not shipped in the RPM.

# The task user: the user who does the lab on that machine. test-lab.sh
# sets SOLVE_USER to student for workstation and multi-node labs and to
# the configured SSH_USER (opsadmin) for server targets. LAB_USER is the
# same value as labctl exports it to setup.sh, grade.sh and cleanup.sh.
SOLVE_USER="${SOLVE_USER:-${LAB_USER:-student}}"

# run_as_student [<script>]
# Run shell code as the task user (SOLVE_USER; the name is historical: on
# a server target it is opsadmin, who has full sudo) in a login shell
# (home directory as the working directory, the user's environment), with
# bash -euo pipefail.
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
