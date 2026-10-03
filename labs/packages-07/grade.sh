#!/bin/bash
# packages-07 grader
#
# The configuration checks compare the active lines of /etc/chrony.conf
# (comments and blank lines left out, whitespace collapsed) with the
# default chrony.conf of the package, which setup.sh recorded at the
# first start. The package checks use the package list of the setup
# transaction from the state file and the package snapshot of the
# first start (lib/packages.sh).
source /opt/linux-labs/lib/grading.sh

LAB=packages-07
STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/$LAB"
REF="$STATE_DIR/$LAB.d/chrony.conf.default"
SNAP="$STATE_DIR/$LAB.packages/packages"
CONF=/etc/chrony.conf
LOCAL1='allow 172.25.250.0/24'
LOCAL2='local stratum 10'

# active_lines <file>: the directives, one per line, whitespace
# collapsed; chrony treats lines that start with # % ; or ! as comments
active_lines() {
	awk '
		NF {
			$1 = $1
			if ($0 !~ /^[#%;!]/) print
		}
	' "$1" 2>/dev/null
}

chronyd_ok() {
	systemctl is-enabled --quiet chronyd && systemctl is-active --quiet chronyd
}

# chronyd -p exits 0 and prints no error or warning: the output is the
# configuration only, without the time-stamped log lines
parse_ok() {
	local out
	out=$(chronyd -p 2>&1) || return 1
	! printf '%s\n' "$out" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T|Fatal|no longer supported'
}

has_line() {
	active_lines "$CONF" | grep -qxF "$1"
}

# Every active line except one copy of each local line is in the
# default, and the default has no line that is missing here
rest_is_default() {
	local have want
	[ -r "$REF" ] && [ -r "$CONF" ] || return 1
	have=$(active_lines "$CONF" | awk -v a="$LOCAL1" -v b="$LOCAL2" '
		$0 == a && !sa { sa = 1; next }
		$0 == b && !sb { sb = 1; next }
		{ print }' | LC_ALL=C sort)
	want=$(active_lines "$REF" | LC_ALL=C sort)
	[ "$have" = "$want" ]
}

no_leftovers() {
	[ -z "$(find /etc \( -name 'chrony*.rpmnew' -o -name 'chrony*.rpmsave' \) \
		-print -quit 2>/dev/null)" ]
}

# None of the packages that the setup transaction installed
setup_packages_gone() {
	local new p
	new=$(sed -n 's/^new=//p' "$STATE_FILE" | head -n 1)
	[ -n "$new" ] || return 1
	for p in $new; do
		rpm -q "$p" >/dev/null 2>&1 && return 1
	done
	return 0
}

# Every package of the first start is still installed
old_packages_kept() {
	local now
	[ -r "$SNAP" ] || return 1
	now=$(rpm -qa --qf '%{NAME}.%{ARCH}\n' | LC_ALL=C sort -u)
	[ -z "$(grep -v '^gpg-pubkey-' "$SNAP" | LC_ALL=C sort -u |
		LC_ALL=C comm -23 - <(printf '%s\n' "$now"))" ]
}

grade_begin packages-07
grade_require_state packages-07 "$STATE_FILE"

criterion "chronyd is enabled and running" chronyd_ok
criterion "chronyd -p reads the configuration without errors" parse_ok
criterion "$CONF has the line: $LOCAL1" has_line "$LOCAL1"
criterion "$CONF has the line: $LOCAL2" has_line "$LOCAL2"
criterion "All other lines of $CONF are the package default" rest_is_default
criterion "No chrony .rpmnew or .rpmsave file is left under /etc" no_leftovers
criterion "The packages of the setup transaction are removed" setup_packages_gone
criterion "Every package from before the lab is still installed" old_packages_kept
grade_end
