#!/bin/bash
# logging-01 grader
source /opt/linux-labs/lib/grading.sh

STATE_FILE=/opt/linux-labs/state/logging-01

grade_begin logging-01
grade_require_state logging-01 "$STATE_FILE"
DIR=$(sed -n 's/^DIR=//p' "$STATE_FILE")
RID=$(sed -n 's/^RID=//p' "$STATE_FILE")

# Lab entries as plain text lines: "labjournal[PID]: level=..." or
# "labjournal: level=...", the message follows the colon
ENTRY_RE='labjournal(\[[0-9]+\])?: level='

# Messages of this run in the order they were written
M_INFO1="level=info $RID user session opened"
M_WARN1="level=warning $RID certificate expires in 14 days"
M_ERR1="level=err $RID backup job failed"
M_NOTICE="level=notice $RID configuration reloaded"
M_CRIT="level=crit $RID power supply redundancy lost"
M_WARN2="level=warning $RID disk usage above 80 percent"
M_ERR2="level=err $RID mail queue is not draining"
M_INFO2="level=info $RID health check completed"

# has_all FILE MSG...: the file contains every message
has_all() {
	local f="$1" m
	shift
	[ -s "$f" ] || return 1
	for m in "$@"; do
		grep -qF "$m" "$f" || return 1
	done
}

# only_levels FILE LEVEL...: every line is a journalctl header or a lab
# entry whose level is one of the given levels
only_levels() {
	local f="$1" re line
	shift
	[ -s "$f" ] || return 1
	re="$ENTRY_RE($(IFS='|'; echo "$*"))[ ]"
	while IFS= read -r line; do
		case "$line" in
			"") continue ;;
			"-- "*) continue ;;
		esac
		printf '%s\n' "$line" | grep -qE "$re" || return 1
	done < "$f"
}

# Plain text files
all_has() { has_all "$DIR/all.txt" "$M_INFO1" "$M_WARN1" "$M_ERR1" "$M_NOTICE" "$M_CRIT" "$M_WARN2" "$M_ERR2" "$M_INFO2"; }
all_only() { only_levels "$DIR/all.txt" info warning err notice crit; }
err_has() { has_all "$DIR/errors.txt" "$M_ERR1" "$M_CRIT" "$M_ERR2"; }
err_only() { only_levels "$DIR/errors.txt" crit err; }
warn_has() { has_all "$DIR/warnings.txt" "$M_WARN1" "$M_ERR1" "$M_CRIT" "$M_WARN2" "$M_ERR2"; }
warn_only() { only_levels "$DIR/warnings.txt" crit err warning; }

# latest.txt: the three newest lab entries of this run, newest first
latest_ok() {
	local f="$DIR/latest.txt" got want
	only_levels "$f" info warning err notice crit || return 1
	got=$(grep -E "$ENTRY_RE" "$f" | sed -E "s/^.*$ENTRY_RE/level=/")
	want=$(printf '%s\n' "$M_INFO2" "$M_ERR2" "$M_WARN2")
	[ "$got" = "$want" ]
}

# errors.json: JSON, one entry per line, only lab entries up to err
json_has() {
	local f="$DIR/errors.json"
	[ -s "$f" ] || return 1
	has_all "$f" "$M_ERR1" "$M_CRIT" "$M_ERR2"
}
json_only() {
	local f="$DIR/errors.json" line
	[ -s "$f" ] || return 1
	while IFS= read -r line; do
		[ -n "$line" ] || continue
		case "$line" in
			"{"*"}") ;;
			*) return 1 ;;
		esac
		printf '%s\n' "$line" | grep -qF '"SYSLOG_IDENTIFIER":"labjournal"' || return 1
		printf '%s\n' "$line" | grep -qE '"PRIORITY":"[0-3]"' || return 1
	done < "$f"
}

criterion "all.txt contains the 8 entries of identifier labjournal" all_has
criterion "all.txt contains no other entries" all_only
criterion "errors.txt has the 3 labjournal entries of err or worse" err_has
criterion "errors.txt contains no other entries" err_only
criterion "warnings.txt has the 5 labjournal entries of warning or worse" warn_has
criterion "warnings.txt contains no other entries" warn_only
criterion "latest.txt has the 3 newest labjournal entries, newest first" latest_ok
criterion "errors.json has the 3 labjournal entries of err or worse" json_has
criterion "errors.json is JSON with one entry per line, no other entries" json_only
grade_end
