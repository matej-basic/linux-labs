#!/usr/bin/env bash
# Static checker for the lab framework 2.0 contract (see CLAUDE.md).
#
# Usage: scripts/check-labs.sh [--strict] [<lab>...]
#
# Without lab names it checks every directory under labs/. A lab with a
# task.txt is a converted lab and must meet the full contract. A lab
# without task.txt is a legacy lab: it is reported as LEGACY and does not
# fail the run, unless --strict is given.
#
# The shellcheck tool is taken from PATH, else run through docker
# (koalaman/shellcheck:stable), else skipped with a note on stderr. Set
# SHELLCHECK=none to skip it.
#
# Exit status: 0 when every checked lab passes, 1 otherwise, 2 on usage
# errors. Runs on bash 3.2 (macOS) and later.

# The c_* check functions are called through check()
# shellcheck disable=SC2329

set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
# shellcheck source-path=SCRIPTDIR source=../src/opt/linux-labs/lib/grading.sh
source "$ROOT_DIR/src/opt/linux-labs/lib/grading.sh"

MAX_WIDTH=72
# Keep in sync with render_task in src/usr/bin/labctl
PLACEHOLDERS="EL_MAJOR ARCH HOSTNAME LAB_USER NODE_COUNT NODE1_IP NODE2_IP NODE3_IP NODE4_IP NODE5_IP NODE6_IP NODE7_IP NODE8_IP NODE9_IP"
SECTIONS="OBJECTIVE|TOPOLOGY|PREREQUISITES|TASKS|EXPECTED RESULT|PRACTICE (not graded)|NOTES|GRADING"
CATEGORIES="Database Replication|Databases|DNS|Files|Firewall|High Availability Clustering|Load Balancing|Logging|Networking|Packages|Scheduling|SELinux|Storage|Systemd|Users|Web Servers"
LAB_FILES="setup.sh grade.sh cleanup.sh description.txt task.txt solution.md solve.sh"
SCRIPTS="setup.sh grade.sh cleanup.sh solve.sh"
# task.txt describes the end state, never how to reach it. A body line is
# flagged when, after its indent and an optional "- " or "N. " marker, it
# starts with a prompt ("$ " or "# ") or with one of these commands followed
# by an argument (for find and mount the argument must start with - / . ~ $),
# or when it contains a brace pattern ({a,b}) or a glob (name*).
TASK_COMMANDS="touch mkdir mv cp rm rmdir ln chmod chown chgrp setfacl useradd groupadd usermod userdel groupdel passwd dnf yum rpm systemctl firewall-cmd nmcli semanage restorecon setsebool chcon mount umount mkswap swapon lvcreate pvcreate vgcreate lvextend tar curl wget crontab sed awk echo cat find grep sudo"
# Escape for false positives: scripts/check-labs.allow (see the file)
TASK_ALLOW="$ROOT_DIR/scripts/check-labs.allow"
# Allowed shellcheck exclusions for lab scripts:
#   SC1091  not following a sourced file (lab scripts source absolute
#           /opt/linux-labs paths that do not exist in the checkout)
SHELLCHECK_OPTS="-s bash -e SC1091"

usage() {
	echo "Usage: $0 [--strict] [<lab>...]" >&2
}

strict=0
labs=()
while [ "$#" -gt 0 ]; do
	case "$1" in
		--strict) strict=1 ;;
		-h|--help) usage; exit 0 ;;
		-*) echo "Error: unknown option: $1" >&2; usage; exit 2 ;;
		*) labs+=("${1%/}") ;;
	esac
	shift
done

if [ "${#labs[@]}" -eq 0 ]; then
	for d in "$ROOT_DIR"/labs/*/; do
		d="${d%/}"
		labs+=("${d##*/}")
	done
fi

for lab in "${labs[@]}"; do
	if [ ! -d "$ROOT_DIR/labs/$lab" ]; then
		echo "Error: no such lab: $lab" >&2
		exit 2
	fi
done

# Choose a shellcheck runner
SC_MODE=none
if [ "${SHELLCHECK:-}" = "none" ]; then
	SC_MODE=none
elif command -v shellcheck >/dev/null 2>&1; then
	SC_MODE=local
elif command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
	SC_MODE=docker
fi
if [ "$SC_MODE" = "none" ]; then
	echo "Note: shellcheck not available, shellcheck criteria are skipped" >&2
fi

run_shellcheck() {
	# Arguments are paths relative to ROOT_DIR
	# shellcheck disable=SC2086 # SHELLCHECK_OPTS is a word list
	case "$SC_MODE" in
		local) (cd "$ROOT_DIR" && shellcheck $SHELLCHECK_OPTS "$@") ;;
		docker) docker run --rm -v "$ROOT_DIR:/mnt:ro" -w /mnt koalaman/shellcheck:stable $SHELLCHECK_OPTS "$@" ;;
	esac
}

DETAILS=$(mktemp "${TMPDIR:-/tmp}/check-labs.XXXXXX")
trap 'rm -f "$DETAILS"' EXIT

# check <text> <function> [args...]
# The function prints one line per problem. No output means PASS.
# On FAIL the first 10 problem lines are printed under the criterion.
check() {
	local text="$1"
	shift
	"$@" >"$DETAILS" 2>&1
	if [ -s "$DETAILS" ]; then
		criterion_result "$text" 1
		head -n 10 "$DETAILS" | sed 's/^/    /'
		if [ "$(wc -l <"$DETAILS")" -gt 10 ]; then
			echo "    ..."
		fi
	else
		criterion_result "$text" 0
	fi
}

# --- individual checks; $D is the lab directory, $LAB the lab name -------

c_file_set() {
	local f name
	for f in $LAB_FILES; do
		[ -f "$D/$f" ] || echo "missing: $f"
	done
	for f in "$D"/* "$D"/.[!.]*; do
		[ -e "$f" ] || continue
		name="${f##*/}"
		case " $LAB_FILES " in
			*" $name "*) ;;
			*) echo "unexpected: $name" ;;
		esac
	done
}

c_exec_disk() {
	local f
	for f in $SCRIPTS; do
		[ -f "$D/$f" ] || continue
		[ -x "$D/$f" ] || echo "not executable on disk: $f"
	done
}

c_exec_git() {
	local f mode
	git -C "$ROOT_DIR" rev-parse --git-dir >/dev/null 2>&1 || return 0
	for f in $SCRIPTS; do
		mode=$(git -C "$ROOT_DIR" ls-files -s -- "labs/$LAB/$f" | awk '{print $1}')
		# Untracked files are checked on disk only
		[ -z "$mode" ] && continue
		[ "$mode" = "100755" ] || echo "mode $mode in the git index: $f"
	done
}

c_shebang() {
	local f
	for f in $SCRIPTS; do
		[ -f "$D/$f" ] || continue
		[ "$(head -n 1 "$D/$f")" = "#!/bin/bash" ] || echo "first line is not #!/bin/bash: $f"
	done
}

desc_value() {
	sed -n "s/^$1: //p" "$D/description.txt" | head -n 1
}

c_desc_format() {
	local f="$D/description.txt" key keys n
	[ -f "$f" ] || { echo "missing: description.txt"; return; }
	LC_ALL=C grep -n '[^ -~]' "$f" | sed 's/^/non-ASCII or tab: line /'
	grep -n ' $' "$f" | sed 's/^/trailing space: line /'
	grep -vnE '^[a-z_]+: [^ ].*$' "$f" | sed 's/^/not a "key: value" line: /'
	keys=$(sed -n 's/^\([a-z_]*\): .*/\1/p' "$f")
	for key in $keys; do
		case "$key" in
			title|category|complexity|objective|course|course_lab) ;;
			*) echo "unknown key: $key" ;;
		esac
	done
	for key in title category complexity objective course course_lab; do
		n=$(printf '%s\n' "$keys" | grep -cx "$key")
		[ "$n" -gt 1 ] && echo "duplicate key: $key"
	done
	return 0
}

c_desc_required() {
	local key
	[ -f "$D/description.txt" ] || { echo "missing: description.txt"; return; }
	for key in title category complexity objective; do
		[ -n "$(desc_value "$key")" ] || echo "missing key: $key"
	done
	if [ -n "$(desc_value course)" ] && [ -z "$(desc_value course_lab)" ]; then
		echo "course without course_lab"
	fi
	if [ -z "$(desc_value course)" ] && [ -n "$(desc_value course_lab)" ]; then
		echo "course_lab without course"
	fi
	return 0
}

c_desc_values() {
	local v
	[ -f "$D/description.txt" ] || return 0
	v=$(desc_value complexity)
	case "$v" in
		Beginner|Intermediate|Advanced) ;;
		*) echo "complexity is '$v', expected Beginner, Intermediate or Advanced" ;;
	esac
	v=$(desc_value category)
	if ! printf '%s\n' "$v" | grep -qxE "$CATEGORIES"; then
		echo "category '$v' is not one of: $CATEGORIES"
	fi
	v=$(desc_value title)
	[ "${#v}" -le 60 ] || echo "title is longer than 60 characters"
	case "$v" in
		*.) echo "title ends with a period" ;;
	esac
	v=$(desc_value course_lab)
	if [ -n "$v" ] && ! printf '%s\n' "$v" | grep -qxE '[0-9][0-9]'; then
		echo "course_lab '$v' is not two digits"
	fi
	return 0
}

# Text rules shared by task.txt and solution.md
c_text_rules() {
	local f="$D/$1"
	[ -f "$f" ] || { echo "missing: $1"; return; }
	LC_ALL=C grep -n '[^ -~]' "$f" | cut -c1-60 | sed 's/^/non-ASCII, tab or control character: line /'
	grep -n ' $' "$f" | cut -d: -f1 | sed 's/^/trailing space: line /'
	LC_ALL=C awk -v max="$MAX_WIDTH" 'length($0) > max && $0 !~ /https?:\/\// { print "longer than " max " columns: line " NR }' "$f"
	grep -nE '[[:alnum:])]!( |$)' "$f" | cut -d: -f1 | sed 's/^/exclamation mark: line /'
	[ -z "$(tail -c 1 "$f")" ] || echo "no newline at end of file"
	[ -n "$(tail -n 1 "$f")" ] || echo "blank line at end of file"
	[ -n "$(head -n 1 "$f")" ] || echo "blank line at start of file"
	awk 'prev == "" && $0 == "" && NR > 1 { print "two blank lines in a row: line " NR } { prev = $0 }' "$f"
}

is_multinode() {
	grep -q 'load-config\.sh' "$D/setup.sh" "$D/grade.sh" "$D/cleanup.sh" 2>/dev/null
}

c_task_sections() {
	local f="$D/task.txt" line n=0 last=-1 idx s i heads="" prevblank=1 expect_body=0
	[ -f "$f" ] || { echo "missing: task.txt"; return; }
	[ "$(head -n 1 "$f")" = "OBJECTIVE" ] || echo "first line is not OBJECTIVE"
	while IFS= read -r line || [ -n "$line" ]; do
		n=$((n + 1))
		if [ "$expect_body" -eq 1 ]; then
			case "$line" in
				"  "[!\ ]*|"   "*) ;;
				*) echo "line $n: heading must be followed directly by an indented body line" ;;
			esac
			expect_body=0
		fi
		case "$line" in
			"") prevblank=1; continue ;;
			" "*)
				case "$line" in
					"  "*) ;;
					*) echo "line $n: body lines are indented by at least two spaces" ;;
				esac
				prevblank=0
				continue
				;;
		esac
		# A line in column 0 must be a known section heading
		idx=-1
		i=0
		IFS='|'
		for s in $SECTIONS; do
			[ "$line" = "$s" ] && idx=$i
			i=$((i + 1))
		done
		unset IFS
		if [ "$idx" -lt 0 ]; then
			echo "line $n: '$line' is not a section heading (body lines start with two spaces)"
		else
			[ "$idx" -gt "$last" ] || echo "line $n: section $line is out of order or repeated"
			last=$idx
			[ "$n" -eq 1 ] || [ "$prevblank" -eq 1 ] || echo "line $n: no blank line before $line"
			heads="$heads|$line|"
			expect_body=1
		fi
		prevblank=0
	done <"$f"
	[ "$expect_body" -eq 0 ] || echo "last section has no body"
	for s in OBJECTIVE TASKS NOTES GRADING; do
		case "$heads" in
			*"|$s|"*) ;;
			*) echo "missing required section: $s" ;;
		esac
	done
	if is_multinode; then
		case "$heads" in
			*"|TOPOLOGY|"*) ;;
			*) echo "multi-node lab without TOPOLOGY section" ;;
		esac
	else
		case "$heads" in
			*"|TOPOLOGY|"*) echo "TOPOLOGY section in a single-node lab" ;;
		esac
	fi
	return 0
}

# Print the body of one task.txt section
task_section() {
	awk -v s="$1" '
		/^[^ ]/ { insec = ($0 == s); next }
		insec { print }
	' "$D/task.txt"
}

c_task_numbering() {
	local nums expect=1 x
	[ -f "$D/task.txt" ] || return 0
	nums=$(task_section TASKS | sed -n 's/^  \([0-9][0-9]*\)\. .*/\1/p')
	[ -n "$nums" ] || { echo "TASKS has no numbered items ('  1. ...')"; return; }
	for x in $nums; do
		[ "$x" -eq "$expect" ] || { echo "TASKS item $x found where $expect was expected"; return; }
		expect=$((expect + 1))
	done
	task_section TASKS | grep -nE '^ ?[0-9]+\.|^   +[0-9]+\. ' | sed 's/^/TASKS numbered item not at two-space indent: /'
	return 0
}

c_task_placeholders() {
	local f="$D/task.txt" p rest
	[ -f "$f" ] || return 0
	# shellcheck disable=SC2013 # placeholders contain no spaces
	for p in $(grep -oE '\{\{[^}]*\}\}' "$f" | sort -u); do
		case " $PLACEHOLDERS " in
			*" ${p:2:${#p}-4} "*) ;;
			*) echo "unknown placeholder: $p" ;;
		esac
	done
	rest=$(sed -E 's/\{\{[A-Z0-9_]+\}\}//g' "$f" | grep -nE '\{\{|\}\}')
	[ -z "$rest" ] || printf '%s\n' "$rest" | cut -d: -f1 | sed 's/^/stray {{ or }}: line /'
	return 0
}

# Print "line N: <kind>: <text>" for every task.txt line that looks like a
# solving command, brace pattern or glob and is not in check-labs.allow
c_task_no_commands() {
	local f="$D/task.txt" n kind text entry ln
	[ -f "$f" ] || return 0
	awk -v cmds="$TASK_COMMANDS" '
		BEGIN { k = split(cmds, a, " "); for (i = 1; i <= k; i++) c[a[i]] = 1 }
		/^[^ ]/ || /^$/ { next }
		{
			s = $0; sub(/^ +/, "", s)
			t = s; sub(/^(- |[0-9]+[.] )/, "", t)
			split(t, w, " "); first = w[1]; arg = w[2]
			kinds = ""
			if (s ~ /^[$#]( |$)/) kinds = kinds ", prompt"
			if (arg != "" && ((first in c) || first ~ /^mkfs([.][a-z0-9]+)?$/)) {
				if (!((first == "find" || first == "mount") && arg !~ /^[-\/.~$]/))
					kinds = kinds ", command " first
			}
			if (s ~ /[{][^{} ]*,[^{} ]*[}]/) kinds = kinds ", brace pattern"
			if (s ~ /[A-Za-z0-9_.][*]|[*][A-Za-z0-9_.]/) kinds = kinds ", glob"
			if (kinds != "") print NR "\t" substr(kinds, 3) "\t" s
		}
	' "$f" | while IFS="$(printf '\t')" read -r n kind text; do
		entry="$LAB: $text"
		ln=""
		[ -f "$TASK_ALLOW" ] && ln=$(grep -nFx -- "$entry" "$TASK_ALLOW" | head -n 1 | cut -d: -f1)
		if [ -n "$ln" ]; then
			# An allowlist entry needs a "# reason" comment on the line above
			if [ "$ln" -gt 1 ] && sed -n "$((ln - 1))p" "$TASK_ALLOW" | grep -qE '^# .+'; then
				continue
			fi
			echo "line $n: allowlist entry without a '# reason' line above it"
			continue
		fi
		echo "line $n: $kind: $text"
	done
	return 0
}

c_task_grading() {
	[ -f "$D/task.txt" ] || return 0
	task_section GRADING | grep -qx "  labctl grade $LAB" || echo "GRADING has no line '  labctl grade $LAB'"
}

c_solution_headings() {
	local f="$D/solution.md" title heads
	[ -f "$f" ] || { echo "missing: solution.md"; return; }
	title=$(desc_value title)
	[ "$(head -n 1 "$f")" = "# $LAB: $title" ] || echo "first line is not '# $LAB: $title'"
	[ "$(grep -c '^# ' "$f")" -eq 1 ] || echo "more than one '# ' heading"
	heads=$(grep '^## ' "$f" | tr '\n' '|')
	[ "$heads" = "## Solution|## Verification|## Explanation|" ] \
		|| echo "'## ' headings are '${heads}', expected Solution, Verification, Explanation in that order"
	[ $(($(grep -c '^ *```' "$f") % 2)) -eq 0 ] || echo "unbalanced code fences"
	return 0
}

solution_section() {
	awk -v s="## $1" '
		/^## / { insec = ($0 == s); next }
		insec { print }
	' "$D/solution.md"
}

c_solution_steps() {
	local nums expect=1 x
	[ -f "$D/solution.md" ] || return 0
	nums=$(solution_section Solution | sed -n 's/^\([0-9][0-9]*\)\. .*/\1/p')
	[ -n "$nums" ] || { echo "## Solution has no numbered steps ('1. [user] ...')"; return; }
	for x in $nums; do
		[ "$x" -eq "$expect" ] || { echo "step $x found where $expect was expected"; break; }
		expect=$((expect + 1))
	done
	solution_section Solution | grep -E '^[0-9]+\. ' | grep -vE '^[0-9]+\. \[(user|sudo)\] ' \
		| cut -c1-50 | sed 's/^/step not marked [user] or [sudo]: /'
	return 0
}

c_solution_verification() {
	[ -f "$D/solution.md" ] || return 0
	solution_section Verification | grep -q "labctl grade $LAB" || echo "## Verification does not run labctl grade $LAB"
}

c_grade_library() {
	local f="$D/grade.sh"
	[ -f "$f" ] || { echo "missing: grade.sh"; return; }
	grep -qE '^(source|\.) /opt/linux-labs/lib/grading\.sh$' "$f" || echo "does not source /opt/linux-labs/lib/grading.sh"
	grep -qE "^grade_begin $LAB\$" "$f" || echo "no 'grade_begin $LAB' line"
	grep -qE '^grade_end$' "$f" || echo "no 'grade_end' line"
	return 0
}

c_grade_legacy() {
	local f="$D/grade.sh"
	[ -f "$f" ] || return 0
	grep -n 'colors\.sh' "$f" | cut -d: -f1 | sed 's/^/sources colors.sh: line /'
	grep -nE '^[[:space:]]*(function[[:space:]]+)?(pass|fail|ok|err)[[:space:]]*\(\)' "$f" | cut -d: -f1 | sed 's/^/defines its own pass\/fail helper: line /'
	grep -nE '(^[[:space:]]*|[;&|{(][[:space:]]*|then[[:space:]]+|else[[:space:]]+|do[[:space:]]+)(pass|fail)[[:space:]]+["$]' "$f" | cut -d: -f1 | sed 's/^/calls pass or fail: line /'
	grep -n 'NO PASS' "$f" | cut -d: -f1 | sed 's/^/uses the retired NO PASS label: line /'
	grep -nE '^[[:space:]]*set[[:space:]]+(-[a-zA-Z]*e|-o[[:space:]]+errexit)' "$f" | cut -d: -f1 | sed 's/^/uses set -e: line /'
	return 0
}

c_setup_quiet() {
	local f="$D/setup.sh"
	[ -f "$f" ] || return 0
	grep -nE 'OBJECTIVE|={10,}|^[[:space:]]*clear[[:space:]]*$' "$f" | cut -d: -f1 | sed 's/^/task banner or clear in setup.sh: line /'
	return 0
}

c_solve_directives() {
	local f="$D/solve.sh" line n=0 count=0 none=0
	[ -f "$f" ] || { echo "missing: solve.sh"; return; }
	while IFS= read -r line; do
		n=$((n + 1))
		case "$line" in
			"# solve:"*) ;;
			*) continue ;;
		esac
		count=$((count + 1))
		if printf '%s\n' "$line" | grep -qE '^# solve: path /[^ ]*$'; then :
		elif printf '%s\n' "$line" | grep -qE '^# solve: package [A-Za-z0-9._+-]+$'; then :
		elif [ "$line" = "# solve: reboot" ]; then :
		elif [ "$line" = "# solve: none" ]; then none=1
		else echo "line $n: invalid directive: $line"
		fi
	done <"$f"
	[ "$count" -gt 0 ] || echo "no '# solve:' directive (use '# solve: none' if the lab creates nothing)"
	[ "$none" -eq 0 ] || [ "$count" -eq 1 ] || echo "'# solve: none' combined with other directives"
	# shellcheck disable=SC2016 # literal line
	grep -qxF 'source "$(dirname "$0")/solve-lib.sh"' "$f" || echo "does not source \"\$(dirname \"\$0\")/solve-lib.sh\""
	return 0
}

c_bash_n() {
	local f
	for f in $SCRIPTS; do
		[ -f "$D/$f" ] || continue
		bash -n "$D/$f" 2>&1
	done
}

c_shellcheck() {
	local f args=()
	for f in $SCRIPTS; do
		[ -f "$D/$f" ] && args+=("labs/$LAB/$f")
	done
	[ "${#args[@]}" -gt 0 ] || return 0
	run_shellcheck "${args[@]}" | grep -E '^In |SC[0-9]{4}' | sed 's/^ *//'
	return 0
}

check_lab() {
	LAB="$1"
	D="$ROOT_DIR/labs/$LAB"
	grade_reset
	printf 'Checking %s\n\n' "$LAB"
	check "Lab directory has exactly the 2.0 file set" c_file_set
	check "Scripts are executable on disk" c_exec_disk
	check "Scripts are executable in the git index" c_exec_git
	check "Scripts start with #!/bin/bash" c_shebang
	check "description.txt has only known key: value lines" c_desc_format
	check "description.txt has title, category, complexity, objective" c_desc_required
	check "description.txt values are valid" c_desc_values
	check "task.txt follows the text rules" c_text_rules task.txt
	check "task.txt has the required sections in order" c_task_sections
	check "TASKS are numbered from 1" c_task_numbering
	check "task.txt uses only known placeholders" c_task_placeholders
	check "GRADING names labctl grade $LAB" c_task_grading
	check "task.txt states the end state, no solving commands" c_task_no_commands
	check "solution.md follows the text rules" c_text_rules solution.md
	check "solution.md has the 2.0 headings" c_solution_headings
	check "Solution steps are numbered and marked [user] or [sudo]" c_solution_steps
	check "Verification runs labctl grade $LAB" c_solution_verification
	check "grade.sh uses lib/grading.sh" c_grade_library
	check "grade.sh has no legacy pass/fail helpers" c_grade_legacy
	check "setup.sh prints no task banner" c_setup_quiet
	check "solve.sh declares its leftovers and sources solve-lib.sh" c_solve_directives
	check "Scripts pass bash -n" c_bash_n
	if [ "$SC_MODE" != "none" ]; then
		check "Scripts pass shellcheck" c_shellcheck
	fi
	grade_summary
}

results=()
failed=0
converted=0
passed=0
legacy=0
for lab in "${labs[@]}"; do
	if [ ! -f "$ROOT_DIR/labs/$lab/task.txt" ]; then
		legacy=$((legacy + 1))
		results+=("$lab|LEGACY")
		[ "$strict" -eq 1 ] && failed=1
		continue
	fi
	converted=$((converted + 1))
	if check_lab "$lab"; then
		passed=$((passed + 1))
		results+=("$lab|PASS")
	else
		failed=1
		results+=("$lab|FAIL")
	fi
	echo ""
done

echo "Summary"
echo ""
for r in "${results[@]}"; do
	label="${r#*|}"
	if [ "$label" = "LEGACY" ] && [ "$strict" -eq 1 ]; then
		grade_line "${r%%|*} (legacy, no task.txt)" FAIL
	else
		grade_line "${r%%|*}" "$label"
	fi
done
echo ""
if [ "$failed" -eq 0 ]; then
	grade_line "Overall result" PASS
else
	grade_line "Overall result" FAIL
fi
echo "$passed of $converted converted labs pass, $legacy legacy labs not checked."
exit "$failed"
