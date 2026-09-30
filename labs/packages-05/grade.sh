#!/bin/bash
source /opt/linux-labs/lib/colors.sh
rc=0

passcount=0
failcount=0

pass() { echo -e "${GREEN}PASS${RESET}: $*"; ((++passcount)); }
fail() { echo -e "${RED}NO PASS${RESET}: $*"; ((++failcount)); }

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

[ -f /usr/bin/joe ] && [ -x /usr/bin/joe ] && pass "/usr/bin/joe exists and is executable" || { fail "/usr/bin/joe not found or not executable"; rc=1; }
[ -e /usr/bin/joe ] && ! rpm -qf /usr/bin/joe &>/dev/null && pass "/usr/bin/joe does not come from an RPM package" || { fail "/usr/bin/joe is missing or belongs to an RPM package"; rc=1; }
[ -f /etc/joe/joerc ] && pass "/etc/joe/joerc exists (configuration files in /etc)" || { fail "/etc/joe/joerc not found"; rc=1; }
[ ! -e /usr/local/bin/joe ] && pass "joe was not installed under /usr/local" || { fail "/usr/local/bin/joe exists (default prefix was used)"; rc=1; }
joe_runs && pass "joe starts and runs" || { fail "joe did not start correctly"; rc=1; }

echo ""
echo "Results: $passcount passed, $failcount failed"

if [[ $failcount -eq 0 ]]; then
	pass "Lab completed successfully"
	exit 0
else
	fail "Lab incomplete"
	exit 1
fi
