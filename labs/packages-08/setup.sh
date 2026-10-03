#!/bin/bash
# packages-08 setup: Node.js 20 from the dnf module stream nodejs:20 on
# servera. The stream is enabled and its common profile is installed.
# Prints nothing on success.
#
# The first run records the package set and /etc/dnf/modules.d
# (pkg_snapshot). A later run first removes every Node.js package an
# earlier start or a solution left, then sets the module up again, so
# the starting state is always the same.
set -eu
source /opt/linux-labs/lib/packages.sh

LAB=packages-08
MODULE=nodejs
OLD=20
STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/$LAB"

command -v dnf >/dev/null 2>&1 || { echo "Error: dnf not found." >&2; exit 1; }

# run <what> <command...>: run a command quietly, show its output and
# an error message when it fails
run() {
	local what=$1 out
	shift
	if ! out=$("$@" </dev/null 2>&1); then
		printf '%s\n' "$out" >&2
		echo "Error: could not $what." >&2
		exit 1
	fi
}

# The installed Node.js packages: from any nodejs module stream, or
# named nodejs, nodejs-* or npm (the non-modular nodejs of EL9)
node_packages() {
	rpm -qa --qf '%{NAME}\t%{MODULARITYLABEL}\n' |
		awk -F '\t' -v m="$MODULE:" '
			index($2, m) == 1 || $1 == "npm" || $1 == "nodejs" ||
			$1 ~ /^nodejs-/ { print $1 }' | LC_ALL=C sort -u
}

# Task user, recorded for the grader
user="${LAB_USER:-student}"
if ! id "$user" &>/dev/null; then
	user=$(getent passwd | awk -F: '$3 >= 1000 && $3 < 60000 { print $1; exit }')
	user="${user:-root}"
fi

pkg_snapshot "$LAB"

# Start over: no Node.js package, no stream chosen
old=$(node_packages | tr '\n' ' ')
if [ -n "$old" ]; then
	# shellcheck disable=SC2086 # one word per package
	run "remove the Node.js packages $old" \
		dnf -y --disablerepo='*' remove $old
fi
run "reset the module $MODULE" dnf -y module reset "$MODULE"

# The starting point: stream 20 and its common profile
run "enable the module stream $MODULE:$OLD" \
	dnf -y module enable "$MODULE:$OLD"
run "install the profile $MODULE:$OLD/common" \
	dnf -y module install "$MODULE:$OLD/common"

label=$(rpm -q --qf '%{MODULARITYLABEL}' nodejs 2>/dev/null || true)
case "$label" in
"$MODULE:$OLD:"*) ;;
*)
	echo "Error: nodejs is not installed from the stream $MODULE:$OLD." >&2
	exit 1
	;;
esac

mkdir -p "$STATE_DIR"
tmp="$STATE_FILE.tmp"
echo "user=$user" > "$tmp"
chmod 0644 "$tmp"
mv "$tmp" "$STATE_FILE"
exit 0
