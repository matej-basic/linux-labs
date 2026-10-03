#!/bin/bash
# packages-08 grader
#
# Works without the network: the stream and profile come from
# /etc/dnf/modules.d/nodejs.module, which dnf writes when a stream is
# enabled or a profile installed, and the origin of each package from
# its MODULARITYLABEL tag (module:stream:version:context), which dnf
# keeps in the rpm database.
source /opt/linux-labs/lib/grading.sh

LAB=packages-08
MODULE=nodejs
OLD=20
NEW=22
STATE_FILE=/opt/linux-labs/state/$LAB
MODFILE=/etc/dnf/modules.d/$MODULE.module

# modvalue <key>: the value of a key in the module file
modvalue() {
	awk -F= -v k="$1" '
		{ gsub(/[ \t]/, "") }
		$1 == k { print $2; exit }' "$MODFILE" 2>/dev/null
}

stream_enabled() {
	[ "$(modvalue state)" = enabled ] && [ "$(modvalue stream)" = "$NEW" ]
}

profile_installed() {
	stream_enabled || return 1
	modvalue profiles | tr ',' '\n' | grep -qx common
}

# from_new <package>: the package is installed, from stream NEW
from_new() {
	local label
	label=$(rpm -q --qf '%{MODULARITYLABEL}\n' "$1" 2>/dev/null) || return 1
	! printf '%s\n' "$label" | grep -qv "^$MODULE:$NEW:"
}

# Name and module label of every installed package
labels() {
	rpm -qa --qf '%{NAME}\t%{MODULARITYLABEL}\n'
}

# Every package from the nodejs module, or named like one of its
# packages, comes from stream NEW
all_from_new() {
	! labels | awk -F '\t' -v m="$MODULE:" -v ok="$MODULE:$NEW:" '
		index($2, m) == 1 || $1 == "npm" || $1 == "nodejs" ||
		$1 ~ /^nodejs-/ {
			if (index($2, ok) != 1) bad = 1
		}
		END { exit !bad }'
}

none_from_old() {
	! labels | awk -F '\t' -v old="$MODULE:$OLD:" '
		index($2, old) == 1 { found = 1 }
		END { exit !found }'
}

user=$(sed -n 's/^user=//p' "$STATE_FILE" 2>/dev/null | head -n 1)
user="${user:-${LAB_USER:-student}}"

node_runs_new() {
	local v
	v=$(runuser -l "$user" -c 'node --version' </dev/null 2>/dev/null) || return 1
	case "$v" in
	"v$NEW".*) return 0 ;;
	*) return 1 ;;
	esac
}

grade_begin packages-08
grade_require_state packages-08 "$STATE_FILE"

criterion "Module stream $MODULE:$NEW is enabled, no other stream" stream_enabled
criterion "Profile $MODULE:$NEW/common is installed" profile_installed
criterion "nodejs is installed from stream $MODULE:$NEW" from_new nodejs
criterion "npm is installed from stream $MODULE:$NEW" from_new npm
criterion "Every installed Node.js package is from $MODULE:$NEW" all_from_new
criterion "No package from stream $MODULE:$OLD is installed" none_from_old
criterion "node --version as $user reports version $NEW" node_runs_new
grade_end
