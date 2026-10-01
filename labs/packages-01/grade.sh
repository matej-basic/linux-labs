#!/bin/bash
# packages-01 grader
source /opt/linux-labs/lib/grading.sh

grade_begin packages-01
grade_require_state packages-01

git_runs() {
	local out
	out=$(/usr/bin/env -i PATH=/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin git --version) || return 1
	[[ "$out" == git\ version\ * ]]
}

criterion "Package git is installed" rpm -q git
criterion "Command git is in the default PATH and runs" git_runs
grade_end
