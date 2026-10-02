#!/usr/bin/env bash
# Static checker for the lab framework 2.0 contract (see docs/author/framework.md).
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
# SHELLCHECK=none to skip it, or SHELLCHECK=docker to force the docker
# image (CI does this so its findings match local runs).
#
# A run without lab names also checks two repo-level criteria: the repo
# root holds only the allowed files and directories, and docs/catalog.md is
# up to date (scripts/gen-catalog.sh regenerates it).
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
CATEGORIES="Containers|Database Replication|Databases|DNS|Files|Firewall|High Availability Clustering|Load Balancing|Logging|Networking|Packages|Scheduling|SELinux|SSH|Storage|Systemd|Users|Web Servers"
# Files and directories allowed in the repo root (tracked, or untracked and
# not ignored). Keep in sync with the root-file rule in CLAUDE.md and
# docs/author/testing.md.
ROOT_ALLOWED="README.md CHANGELOG LICENSE CLAUDE.md .github .gitignore .claude labs src rpm scripts pages docs"
NEEDS_ITEM='(internet|reboot|free-nic|nodes=[0-9]+)'
# Machines a single-node lab can run on (description.txt target:). Keep in
# sync with target_node in src/usr/bin/labctl.
TARGETS="workstation servera serverb serverc"
LAB_FILES="setup.sh grade.sh cleanup.sh description.txt task.txt solution.md solve.sh"
# Optional extra file, repo only (see docs/author/framework.md)
OPTIONAL_FILES="known-issues.md"
SCRIPTS="setup.sh grade.sh cleanup.sh solve.sh"
# task.txt describes the end state, never how to reach it. A body line is
# flagged when, after its indent and an optional "- " or "N. " marker, it
# starts with a prompt ("$ " or "# ") or with one of these commands followed
# by an argument (for find and mount the argument must start with - / . ~ $),
# or when it contains a brace pattern ({a,b}) or a glob (name*).
TASK_COMMANDS="touch mkdir mv cp rm rmdir ln chmod chown chgrp setfacl useradd groupadd usermod userdel groupdel passwd dnf yum rpm systemctl firewall-cmd nmcli semanage restorecon setsebool chcon mount umount mkswap swapon lvcreate pvcreate vgcreate lvextend tar curl wget crontab sed awk echo cat find grep sudo"
# Escape for false positives: scripts/check-labs.allow (see the file)
TASK_ALLOW="$ROOT_DIR/scripts/check-labs.allow"
# A lab installs packages when setup.sh or solve.sh has a line (not a
# comment, echo or printf) that matches this pattern. Such a lab must
# restore the package set with lib/packages.sh: setup.sh sources it and
# calls pkg_snapshot (or pkg_snapshot_node), cleanup.sh sources it and
# calls pkg_restore (or pkg_restore_node). See "Packages" in
# docs/author/framework.md.
PKG_INSTALL_RE='(dnf|yum)( [^|;&]*)? (install|localinstall|reinstall|groupinstall|module install)([^a-z-]|$)|rpm +(-[iU]|--install|--upgrade)'
# Labs that install packages and still have their own package code. The
# per-lab pass converts them to lib/packages.sh one at a time and removes
# each from this list; the criterion fails for a listed lab that already
# uses the helper or no longer installs packages, so the list only shrinks.
PKG_HELPER_PENDING=""
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

repo_checks=0
if [ "${#labs[@]}" -eq 0 ]; then
	repo_checks=1
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
elif [ "${SHELLCHECK:-}" = "docker" ]; then
	SC_MODE=docker
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
			*)
				case " $OPTIONAL_FILES " in
					*" $name "*) ;;
					*) echo "unexpected: $name" ;;
				esac
				;;
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
			title|category|complexity|objective|course|course_lab|needs|target) ;;
			*) echo "unknown key: $key" ;;
		esac
	done
	for key in title category complexity objective course course_lab needs target; do
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

# needs: optional, items in the fixed order internet, reboot, free-nic,
# nodes=N, separated by ", ". reboot must match "# solve: reboot" in solve.sh
# and nodes=N (N >= 2) must go with a TOPOLOGY section in task.txt.
c_desc_needs() {
	local v item rank last=-1 n has_reboot=0 has_nodes=0 solve_reboot=0 topology=0
	[ -f "$D/description.txt" ] || return 0
	v=$(desc_value needs)
	if [ -n "$v" ]; then
		if ! printf '%s\n' "$v" | grep -qE "^$NEEDS_ITEM(, $NEEDS_ITEM)*\$"; then
			echo "needs '$v' is not a list of internet, reboot, free-nic, nodes=N separated by \", \""
			return 0
		fi
		for item in $(printf '%s\n' "$v" | tr -d ','); do
			case "$item" in
				internet) rank=0 ;;
				reboot) rank=1; has_reboot=1 ;;
				free-nic) rank=2 ;;
				nodes=*)
					rank=3
					has_nodes=1
					n="${item#nodes=}"
					[ "$n" -ge 2 ] || echo "needs: $item, N must be at least 2"
					;;
			esac
			if [ "$rank" -le "$last" ]; then
				echo "needs: $item is repeated or out of order (internet, reboot, free-nic, nodes=N)"
			fi
			last=$rank
		done
	fi
	grep -qx '# solve: reboot' "$D/solve.sh" 2>/dev/null && solve_reboot=1
	grep -qx 'TOPOLOGY' "$D/task.txt" 2>/dev/null && topology=1
	[ "$has_reboot" -eq "$solve_reboot" ] || echo "needs reboot and '# solve: reboot' in solve.sh must go together"
	[ "$has_nodes" -eq "$topology" ] || echo "needs nodes=N and a TOPOLOGY section in task.txt must go together"
	return 0
}

# target: required for a single-node lab, one of $TARGETS, and forbidden
# together with needs: nodes=N (a multi-node lab runs on the workstation
# and reaches its nodes itself). Labs that reboot or use a free NIC need a
# server target: the student has no root on the workstation.
c_desc_target() {
	local v needs
	[ -f "$D/description.txt" ] || return 0
	v=$(desc_value target)
	needs=$(desc_value needs)
	case "$needs" in
		*nodes=*)
			[ -z "$v" ] || echo "target: $v together with needs: nodes=N (multi-node labs have no target)"
			return 0
			;;
	esac
	if [ -z "$v" ]; then
		echo "missing key: target (one of: $TARGETS)"
		return 0
	fi
	case " $TARGETS " in
		*" $v "*) ;;
		*) echo "target '$v' is not one of: $TARGETS"; return 0 ;;
	esac
	if [ "$v" = workstation ]; then
		case "$needs" in
			*reboot*|*free-nic*) echo "needs: $needs requires a server target, not workstation" ;;
		esac
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
# solving command, brace pattern or glob and is not in check-labs.allow.
# An optional argument names another file in the same format (used for the
# hints of solution.md).
c_task_no_commands() {
	local f="${1:-$D/task.txt}" n kind text entry ln
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
	case "$heads" in
		"## Solution|## Verification|## Explanation|"|"## Hints|## Solution|## Verification|## Explanation|") ;;
		*) echo "'## ' headings are '${heads}', expected [Hints,] Solution, Verification, Explanation in that order" ;;
	esac
	[ $(($(grep -c '^ *```' "$f") % 2)) -eq 0 ] || echo "unbalanced code fences"
	return 0
}

solution_section() {
	awk -v s="## $1" '
		/^## / { insec = ($0 == s); next }
		insec { print }
	' "$D/solution.md"
}

# The optional "## Hints" section: 2 to 4 numbered items, from 1 without
# gaps (restarting in each "Task N:" group), continuation lines indented by
# three spaces, no code fences. The text rules cover the whole file.
c_hints() {
	local f="$D/solution.md"
	[ -f "$f" ] || return 0
	grep -qx '## Hints' "$f" || return 0
	[ "$(grep -cx '## Hints' "$f")" -eq 1 ] || echo "more than one '## Hints' heading"
	awk '
		function endgroup() {
			if (count < 2 || count > 4)
				print label ": " count " hints, expected 2 to 4"
		}
		/^## / {
			if (insec) { endgroup(); insec = 0 }
			if ($0 == "## Hints") { insec = 1; count = 0; groups = 0; label = "Hints"; expect = 1 }
			next
		}
		!insec { next }
		/^```/ { print "line " NR ": code fence in Hints"; next }
		/^$/ { next }
		/^Task [0-9]+:/ {
			if (groups > 0) endgroup()
			else if (count > 0) print "line " NR ": hints before the first Task group"
			groups++; count = 0; expect = 1; label = $0; next
		}
		/^[0-9]+\. / {
			n = $0; sub(/\..*/, "", n)
			if (n + 0 != expect) print "line " NR ": hint " n " found where " expect " was expected"
			expect = n + 1; count++; next
		}
		/^   [^ ]/ { if (count == 0) print "line " NR ": continuation line before the first hint"; next }
		{ print "line " NR ": not a numbered hint, Task line or continuation indented by 3 spaces" }
		END { if (insec) endgroup() }
	' "$f"
	awk '/^## Solution$/ { sol = NR } /^## Hints$/ { h = NR } END { if (h && sol && h > sol) print "## Hints must come before ## Solution" }' "$f"
}

# Hints are held to the same no-solving-commands rule as task.txt. The
# section is indented by two spaces into a temporary copy that keeps the
# line numbers of solution.md.
c_hints_no_commands() {
	local f="$D/solution.md" tmp
	[ -f "$f" ] || return 0
	grep -qx '## Hints' "$f" || return 0
	tmp=$(mktemp "${TMPDIR:-/tmp}/hints.XXXXXX")
	awk '/^## / { insec = ($0 == "## Hints"); print ""; next } insec && $0 != "" { print "  " $0; next } { print "" }' "$f" >"$tmp"
	c_task_no_commands "$tmp"
	rm -f "$tmp"
}

# The optional known-issues.md: heading "# <lab>: known issues", a blank
# line, then entries "- DATE | RELEASES | STATUS | text" with continuation
# lines indented by exactly two spaces and blank lines only between entries.
# The text rules are checked separately (c_text_rules known-issues.md).
c_known_issues() {
	local f="$D/known-issues.md"
	[ -f "$f" ] || return 0
	[ "$(head -n 1 "$f")" = "# $LAB: known issues" ] || echo "line 1 is not '# $LAB: known issues'"
	if [ "$(wc -l <"$f")" -ge 2 ] && [ -n "$(sed -n 2p "$f")" ]; then echo "line 2 must be blank"; fi
	awk '
		function trim(s) { sub(/^ +/, "", s); sub(/ +$/, "", s); return s }
		function bad_date(d,   m, dd) {
			if (d !~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/) return 1
			m = substr(d, 6, 2) + 0; dd = substr(d, 9, 2) + 0
			return (m < 1 || m > 12 || dd < 1 || dd > 31)
		}
		function bad_releases(r,   k, i, seen, x) {
			if (r == "all") return 0
			k = split(r, x, ", ")
			for (i = 1; i <= k; i++) {
				if (x[i] != "rocky8" && x[i] != "rocky9") return 1
				if (x[i] in seen) return 1
				seen[x[i]] = 1
			}
			return 0
		}
		NR == 1 { next }
		$0 == "" {
			if (NR > 2 && !inentry) print "line " NR ": blank lines belong only between entries"
			if (NR > 2) inentry = 0
			next
		}
		/^- / {
			entries++; inentry = 1
			k = split(substr($0, 3), f, "[ ][|][ ]")
			if (k != 4) {
				print "line " NR ": entry has " k " fields, expected 4 separated by \" | \""
				next
			}
			if (bad_date(f[1])) print "line " NR ": date \"" f[1] "\" is not a valid YYYY-MM-DD"
			if (bad_releases(f[2])) print "line " NR ": releases \"" f[2] "\" must be all, or rocky8 and rocky9 separated by \", \""
			if (f[3] != "open" && f[3] != "workaround" && f[3] != "fixed") print "line " NR ": status \"" f[3] "\" is not open, workaround or fixed"
			if (trim(f[4]) == "") print "line " NR ": empty description"
			next
		}
		/^  [^ ]/ {
			if (!inentry) print "line " NR ": continuation line without an entry above it"
			next
		}
		/^ / { print "line " NR ": continuation lines are indented by exactly two spaces"; next }
		{ print "line " NR ": not an entry (\"- DATE | RELEASES | STATUS | text\"), a continuation line or a blank line" }
		END { if (!entries) print "no entries: remove the file instead of keeping only the heading" }
	' "$f"
}

# The description text of known-issues.md is held to the same
# no-solving-commands rule as task.txt. A temporary copy keeps the line
# numbers: the text of each entry (after the fourth field) and the
# continuation lines are indented by two spaces, everything else is blank.
c_known_issues_no_commands() {
	local f="$D/known-issues.md" tmp
	[ -f "$f" ] || return 0
	tmp=$(mktemp "${TMPDIR:-/tmp}/known.XXXXXX")
	awk '
		/^- / {
			k = split(substr($0, 3), f, "[ ][|][ ]")
			if (k == 4) print "  " f[4]; else print ""
			next
		}
		/^  [^ ]/ { print; next }
		{ print "" }
	' "$f" >"$tmp"
	c_task_no_commands "$tmp"
	rm -f "$tmp"
}

c_known_issues_all() {
	c_known_issues
	c_text_rules known-issues.md
	c_known_issues_no_commands
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

# Lines of setup.sh and solve.sh that install packages
pkg_install_lines() {
	local f
	for f in setup.sh solve.sh; do
		[ -f "$D/$f" ] || continue
		grep -nE "$PKG_INSTALL_RE" "$D/$f" | grep -vE '^[0-9]+:[[:space:]]*#|echo |printf ' | sed "s|^|$f:|"
	done
}

c_packages() {
	local installs uses=0 pending=0 f
	installs=$(pkg_install_lines | sed -n 1p) # reads all input: head would SIGPIPE sed
	for f in setup.sh cleanup.sh; do
		[ -f "$D/$f" ] && grep -qE '^[[:space:]]*(source|\.) /opt/linux-labs/lib/packages\.sh$' "$D/$f" && uses=1
	done
	for f in $PKG_HELPER_PENDING; do
		[ "$f" = "$LAB" ] && pending=1
	done
	if [ "$pending" -eq 1 ]; then
		if [ "$uses" -eq 1 ]; then
			echo "uses lib/packages.sh: remove $LAB from PKG_HELPER_PENDING in scripts/check-labs.sh"
		elif [ -z "$installs" ]; then
			echo "installs no packages: remove $LAB from PKG_HELPER_PENDING in scripts/check-labs.sh"
		fi
		return 0
	fi
	[ -n "$installs" ] || [ "$uses" -eq 1 ] || return 0
	[ -n "$installs" ] && installs=" (${installs%%:[0-9]*}: $(printf '%s\n' "$installs" | cut -d: -f3- | sed 's/^[[:space:]]*//' | cut -c1-40))"
	for f in setup.sh cleanup.sh; do
		[ -f "$D/$f" ] || continue
		grep -qE '^[[:space:]]*(source|\.) /opt/linux-labs/lib/packages\.sh$' "$D/$f" \
			|| echo "$f does not source /opt/linux-labs/lib/packages.sh$installs"
	done
	# Calls outside comment lines, with the lab name literally or as $LAB
	[ -f "$D/setup.sh" ] && ! grep -vE '^[[:space:]]*#' "$D/setup.sh" \
		| grep -qE "(^|[^a-z_])pkg_snapshot(_node)?[[:space:]].*($LAB|\\\$LAB|\\\$\\{LAB\\})|pkg_node_script[[:space:]]+snapshot[[:space:]]" \
		&& echo "setup.sh does not call pkg_snapshot $LAB"
	[ -f "$D/cleanup.sh" ] && ! grep -vE '^[[:space:]]*#' "$D/cleanup.sh" \
		| grep -qE "(^|[^a-z_])pkg_restore(_node)?[[:space:]].*($LAB|\\\$LAB|\\\$\\{LAB\\})|pkg_node_script[[:space:]]+restore[[:space:]]" \
		&& echo "cleanup.sh does not call pkg_restore $LAB"
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

# --- repo-level checks ---------------------------------------------------

c_root_files() {
	local name
	{
		git -C "$ROOT_DIR" ls-files 2>/dev/null
		git -C "$ROOT_DIR" ls-files --others --exclude-standard 2>/dev/null
	} | awk -F/ '{ print $1 }' | sort -u | while IFS= read -r name; do
		# A tracked file that is deleted on disk is not in the root
		[ -e "$ROOT_DIR/$name" ] || [ -L "$ROOT_DIR/$name" ] || continue
		case " $ROOT_ALLOWED " in
			*" $name "*) ;;
			*) echo "not allowed in the repo root: $name" ;;
		esac
	done
}

c_catalog() {
	local tmp
	if [ ! -f "$ROOT_DIR/docs/catalog.md" ]; then
		echo "docs/catalog.md is missing: run scripts/gen-catalog.sh"
		return 0
	fi
	tmp=$(mktemp "${TMPDIR:-/tmp}/catalog.XXXXXX")
	if ! "$ROOT_DIR/scripts/gen-catalog.sh" --md "$tmp" >/dev/null 2>&1; then
		echo "scripts/gen-catalog.sh failed"
	elif ! diff -q "$ROOT_DIR/docs/catalog.md" "$tmp" >/dev/null 2>&1; then
		echo "docs/catalog.md is out of date: run scripts/gen-catalog.sh"
	fi
	rm -f "$tmp"
}

check_repo() {
	grade_reset
	printf 'Checking the repository\n\n'
	check "Repo root holds only the allowed files" c_root_files
	check "docs/catalog.md is up to date" c_catalog
	grade_summary
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
	check "description.txt needs: is valid and matches the lab" c_desc_needs
	check "description.txt target: is valid" c_desc_target
	check "task.txt follows the text rules" c_text_rules task.txt
	check "task.txt has the required sections in order" c_task_sections
	check "TASKS are numbered from 1" c_task_numbering
	check "task.txt uses only known placeholders" c_task_placeholders
	check "GRADING names labctl grade $LAB" c_task_grading
	check "task.txt states the end state, no solving commands" c_task_no_commands
	check "solution.md follows the text rules" c_text_rules solution.md
	check "solution.md has the 2.0 headings" c_solution_headings
	check "Hints (optional) are 2 to 4 numbered items before Solution" c_hints
	check "Hints name no solving commands, brace patterns or globs" c_hints_no_commands
	if [ -f "$D/known-issues.md" ]; then
		check "known-issues.md follows the format" c_known_issues_all
	fi
	check "Solution steps are numbered and marked [user] or [sudo]" c_solution_steps
	check "Verification runs labctl grade $LAB" c_solution_verification
	check "grade.sh uses lib/grading.sh" c_grade_library
	check "grade.sh has no legacy pass/fail helpers" c_grade_legacy
	check "setup.sh prints no task banner" c_setup_quiet
	check "solve.sh declares its leftovers and sources solve-lib.sh" c_solve_directives
	check "Package installs are undone with lib/packages.sh" c_packages
	check "Scripts pass bash -n" c_bash_n
	if [ "$SC_MODE" != "none" ]; then
		check "Scripts pass shellcheck" c_shellcheck
	fi
	grade_summary
}

results=()
failed=0
if [ "$repo_checks" -eq 1 ]; then
	if check_repo; then
		results+=("repository|PASS")
	else
		failed=1
		results+=("repository|FAIL")
	fi
	echo ""
fi
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
