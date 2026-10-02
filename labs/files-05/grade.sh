#!/bin/bash
# files-05 grader: computes every expected answer from the tree under
# /srv/search and compares it with the answer files. Lists are compared
# without regard to order; blank lines and trailing spaces are ignored.
source /opt/linux-labs/lib/grading.sh

ROOT=/srv/search
STATE_FILE=/opt/linux-labs/state/files-05

grade_begin files-05
grade_require_state files-05 "$STATE_FILE"
user=$(sed -n 1p "$STATE_FILE")
dir=$(sed -n 2p "$STATE_FILE")

# norm <file>: the lines of a file without carriage returns, trailing
# spaces and blank lines, sorted
norm() {
	sed -e 's/\r$//' -e 's/[[:space:]]*$//' "$1" | grep -v '^$' | LC_ALL=C sort
}

# norm_paths <file>: as norm, with repeated slashes collapsed
norm_paths() {
	sed -e 's/\r$//' -e 's/[[:space:]]*$//' -e 's|//*|/|g' "$1" |
		grep -v '^$' | LC_ALL=C sort
}

# same_list <file> <expected lines>: the file holds exactly these lines
same_list() {
	[ -f "$1" ] || return 1
	[ "$(norm "$1")" = "$(printf '%s\n' "$2" | grep -v '^$' | LC_ALL=C sort)" ]
}

# same_paths <file> <expected paths>
same_paths() {
	[ -f "$1" ] || return 1
	[ "$(norm_paths "$1")" = "$(printf '%s\n' "$2" | grep -v '^$' | LC_ALL=C sort)" ]
}

# Expected answers, computed as root from the tree
large=$(find "$ROOT" -type f -user builder -size +1M 2>/dev/null)
old=$(find "$ROOT/projects" -type f -mtime +30 2>/dev/null)
setuid=$(find "$ROOT" -type f -perm -4000 2>/dev/null)
links=$(find "$ROOT" -type l 2>/dev/null | wc -l)
errors=$(grep '^ERROR' "$ROOT/logs/app.log" 2>/dev/null | grep -w disk)

# The search for report.txt as the task user, without sudo: its normal
# output and its error messages
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
(cd / && runuser -u "$user" -- env LC_ALL=C find "$ROOT" -name report.txt \
	>"$tmp/out" 2>"$tmp/err")
reports=$(cat "$tmp/out")
denied=$(cat "$tmp/err")

large_ok() { same_paths "$dir/large-files.txt" "$large"; }
old_ok() { same_paths "$dir/old-files.txt" "$old"; }
setuid_ok() { same_paths "$dir/setuid.txt" "$setuid"; }
errors_ok() { same_list "$dir/errors.txt" "$errors"; }
reports_ok() { same_paths "$dir/report-files.txt" "$reports"; }

link_count_ok() {
	local f="$dir/link-count.txt"
	[ -f "$f" ] || return 1
	[ "$(tr -d '[:space:]' < "$f")" = "$links" ]
}

# The error messages exactly as find prints them; typographic quotes from
# a UTF-8 locale count as plain quotes
denied_ok() {
	local f="$dir/denied.txt"
	[ -f "$f" ] && [ -n "$denied" ] || return 1
	sed -e "s/\xe2\x80\x98/'/g" -e "s/\xe2\x80\x99/'/g" "$f" >"$tmp/denied"
	same_list "$tmp/denied" "$denied"
}

criterion "large-files.txt lists the large files of builder" large_ok
criterion "old-files.txt lists the files older than 30 days" old_ok
criterion "setuid.txt lists the files with the SUID bit" setuid_ok
criterion "link-count.txt holds the number of symbolic links" link_count_ok
criterion "errors.txt holds the ERROR lines about disk" errors_ok
criterion "report-files.txt lists the report.txt files found" reports_ok
criterion "denied.txt holds only the error messages of the search" denied_ok
grade_end
