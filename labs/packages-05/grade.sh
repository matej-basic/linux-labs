#!/bin/bash
# packages-05 grader
source /opt/linux-labs/lib/grading.sh

# Start joe in a pseudo-terminal and let it run for two seconds.
# Exit status 124 means timeout had to stop it, so it was running.
# Everything happens in a private temp directory (also used as HOME),
# so neither joe's lock/DEADJOE files nor its state file are left behind.
joe_runs() {
	command -v script &>/dev/null || return 2
	command -v timeout &>/dev/null || return 2
	local tmp st
	tmp=$(mktemp -d) || return 2
	(
		cd "$tmp" || exit 2
		HOME="$tmp" TERM=xterm timeout 2 \
			script -qec "/usr/bin/joe $tmp/joe-test.txt" /dev/null \
			</dev/null &>/dev/null
	)
	st=$?
	pkill -f "/usr/bin/joe $tmp/" &>/dev/null
	rm -rf "$tmp"
	[ "$st" -eq 124 ]
}

# /usr/bin/joe exists and no RPM package owns it
joe_not_from_rpm() {
	[ -e /usr/bin/joe ] && ! rpm -qf /usr/bin/joe &>/dev/null
}

grade_begin packages-05
criterion "/usr/bin/joe is an executable file" test -f /usr/bin/joe -a -x /usr/bin/joe
criterion "/usr/bin/joe does not belong to an RPM package" joe_not_from_rpm
criterion "/etc/joe/joerc exists" test -f /etc/joe/joerc
criterion "/usr/local/bin/joe does not exist" test ! -e /usr/local/bin/joe
criterion "joe starts and keeps running" joe_runs
grade_end
