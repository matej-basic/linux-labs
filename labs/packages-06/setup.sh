#!/bin/bash
# packages-06 setup: no lab repository file, zsh and ksh not installed,
# and every repository disabled. Prints nothing on success.
#
# The package snapshot also records /etc/yum.repos.d, so pkg_restore in
# cleanup.sh puts the repository files back as they were at the first
# start: the disabled repositories come back enabled and labrepo.repo
# goes. setup.sh therefore keeps no copy of the repository files.
set -eu
source /opt/linux-labs/lib/packages.sh

STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/packages-06"
REPO_FILE=/etc/yum.repos.d/labrepo.repo

command -v dnf >/dev/null 2>&1 || { echo "setup: dnf not found" >&2; exit 1; }

# First start only: record the package set and the repository files
pkg_snapshot packages-06

# Left over from an earlier start or a solution
rm -f "$REPO_FILE"
for p in zsh ksh; do
	if rpm -q "$p" >/dev/null 2>&1; then
		dnf -y -q --disablerepo='*' remove "$p" >/dev/null 2>&1 || {
			echo "setup: cannot remove the package $p" >&2
			exit 1
		}
	fi
done

# The ids of all enabled repositories; the first line is the header
enabled_repos() {
	LC_ALL=C dnf -q repolist --enabled </dev/null 2>/dev/null |
		awk 'NR > 1 && NF { print $1 }'
}

# disable_by_hand <id>...: set enabled=0 in the section of each id in
# every repository file (when dnf config-manager is missing)
disable_by_hand() {
	local f ids=" $* "
	for f in /etc/yum.repos.d/*.repo; do
		[ -f "$f" ] || continue
		awk -v ids="$ids" '
			function flush() { if (insec && !done) print "enabled=0" }
			/^[[:space:]]*\[.*\][[:space:]]*$/ {
				flush()
				id = $0
				gsub(/^[[:space:]]*\[|\][[:space:]]*$/, "", id)
				insec = index(ids, " " id " ") > 0
				done = 0
				print
				next
			}
			insec && /^[[:space:]]*enabled[[:space:]]*=/ {
				print "enabled=0"
				done = 1
				next
			}
			{ print }
			END { flush() }
		' "$f" >"$f.lab06" && cat "$f.lab06" >"$f"
		rm -f "$f.lab06"
	done
}

repos=$(enabled_repos | tr '\n' ' ')
if [ -n "${repos// /}" ]; then
	# shellcheck disable=SC2086 # one word per repository id
	if ! dnf config-manager --set-disabled $repos >/dev/null 2>&1; then
		# shellcheck disable=SC2086
		disable_by_hand $repos
	fi
fi
if [ -n "$(enabled_repos)" ]; then
	echo "setup: cannot disable the repositories: $(enabled_repos | tr '\n' ' ')" >&2
	exit 1
fi

mkdir -p "$STATE_DIR"
echo packages-06 >"$STATE_FILE"
chmod 644 "$STATE_FILE"
exit 0
