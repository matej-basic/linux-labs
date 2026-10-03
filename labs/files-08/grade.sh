#!/bin/bash
# files-08 grader: computes every expected report from the data files in
# /srv/textlab with LC_ALL=C and compares it with the report files
# exactly. The only tolerance is a missing newline at the end of a file.
source /opt/linux-labs/lib/grading.sh

DATA=/srv/textlab
LOG="$DATA/access.log"
CSV="$DATA/accounts.csv"
STATE_FILE=/opt/linux-labs/state/files-08
REPORTS="top-ips.txt not-found.txt paths.txt bytes.txt bash-users.txt"
export LC_ALL=C

grade_begin files-08
grade_require_state files-08 "$STATE_FILE"
owner=$(sed -n 1p "$STATE_FILE")
dir=$(sed -n 2p "$STATE_FILE")

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Expected reports, computed from the data
awk '{ c[$1]++ } END { for (ip in c) print c[ip], ip }' "$LOG" 2>/dev/null |
	sort -k1,1nr -k2,2 | head -n 5 >"$tmp/top-ips.txt"
awk '$9 == 404 { n++ } END { print n + 0 }' "$LOG" 2>/dev/null >"$tmp/not-found.txt"
awk '{ print $7 }' "$LOG" 2>/dev/null | sort -u >"$tmp/paths.txt"
awk '$10 != "-" { s += $10 } END { printf "%d\n", s }' "$LOG" 2>/dev/null >"$tmp/bytes.txt"
awk -F, 'NR > 1 && $4 == "/bin/bash" { print $1 ":" $2 }' "$CSV" 2>/dev/null |
	sort -t: -k2,2n >"$tmp/bash-users.txt"

# same_report <name>: the report file is a regular file with exactly the
# expected content; a missing final newline is tolerated
same_report() {
	local f="$dir/$1"
	[ -f "$f" ] && [ ! -L "$f" ] && [ -s "$tmp/$1" ] || return 1
	cp "$f" "$tmp/got" || return 1
	# The last byte is not a newline: add one
	[ -z "$(tail -c 1 "$tmp/got")" ] || echo >>"$tmp/got"
	cmp -s "$tmp/$1" "$tmp/got"
}

dir_owned() {
	[ -d "$dir" ] && [ ! -L "$dir" ] &&
		[ "$(stat -c %U "$dir")" = "$owner" ]
}

reports_owned() {
	local r
	for r in $REPORTS; do
		[ -f "$dir/$r" ] && [ ! -L "$dir/$r" ] || return 1
		[ "$(stat -c %U "$dir/$r")" = "$owner" ] || return 1
	done
}

data_unchanged() {
	sed -n '3,$p' "$STATE_FILE" | (cd / && sha256sum -c --quiet --status -)
}

criterion "Directory $dir exists and belongs to $owner" dir_owned
criterion "The five report files exist and belong to $owner" reports_owned
criterion "top-ips.txt lists the 5 busiest client addresses" same_report top-ips.txt
criterion "not-found.txt holds the number of 404 responses" same_report not-found.txt
criterion "paths.txt lists every distinct path in byte order" same_report paths.txt
criterion "bytes.txt holds the total number of response bytes" same_report bytes.txt
criterion "bash-users.txt lists the /bin/bash accounts by UID" same_report bash-users.txt
criterion "The data files in $DATA are unchanged" data_unchanged
grade_end
