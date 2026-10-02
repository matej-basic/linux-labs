#!/bin/bash
# Shared grading library for linux-labs (lab framework 2.0).
#
# Source it from grade.sh:
#
#   source /opt/linux-labs/lib/grading.sh
#   grade_begin files-04
#   grade_require_state files-04
#   criterion "Directory /srv/archive exists" test -d /srv/archive
#   criterion_result "All 108 files are in place" "$rc"
#   grade_end
#
# Output (Red Hat style, 72 columns, result right-aligned):
#
#   Grading files-04 on workstation
#
#   Directory /srv/archive exists ................................... PASS
#   All 108 files are in place ...................................... FAIL
#
#   Overall result .................................................. FAIL
#   1 of 2 criteria met.
#
# Public functions:
#   grade_begin <lab>              reset counters, print the header line
#   criterion <text> <cmd> [arg...]
#                                  run the command (stdin, stdout and stderr
#                                  go to /dev/null); PASS if it exits 0
#   criterion_result <text> <rc>   record a result computed in shell;
#                                  rc 0 is PASS, anything else is FAIL
#   grade_require_state <lab> [file]
#                                  if the state file (default
#                                  /opt/linux-labs/state/<lab>) is not
#                                  readable, record one FAIL criterion
#                                  "Lab was started with labctl start" and
#                                  end grading (exit 1)
#   grade_abort <text>             record <text> as FAIL and end grading
#   grade_end                      print the summary and exit 0 (all PASS)
#                                  or 1
#
# Lower-level functions, used by the repo tools (check-labs.sh, test-lab.sh):
#   grade_reset                    reset counters without printing
#   grade_summary                  print the summary, return 0 or 1
#   grade_line <text> <label>      print one formatted line, count nothing
#
# criterion and criterion_result always return 0, so a grader keeps going
# after a failed check. Criterion text longer than one line is wrapped at
# word boundaries; continuation lines are indented by two spaces and the
# last line carries the dotted leader and the result. Keep criterion text
# to 64 characters or less so it fits on one line.
#
# Colour applies only to the result word, and only when stdout is a
# terminal and NO_COLOR is unset or empty. LABCTL_COLOR=1 or 0 overrides
# that test: labctl sets it for a grader on a server target, whose stdout
# is the SSH channel, so the colours match what the student's terminal
# would show for a local grader.
#
# The library is compatible with bash 3.2 (macOS, used by the repo tools)
# and safe under "set -u". It does not depend on colors.sh.

GRADE_WIDTH=72

_GRADE_TOTAL=0
_GRADE_PASSED=0

grade_reset() {
	_GRADE_TOTAL=0
	_GRADE_PASSED=0
}


grade_line() {
	local text="$1" label="$2"
	local max line word rest dots n colour reset=""

	# Room for the text: width minus " .. LABEL" (at least two dots)
	max=$((GRADE_WIDTH - ${#label} - 4))
	[ "$max" -lt 20 ] && max=20

	line=""
	rest="$text"
	# Wrap at word boundaries; break words longer than a line
	while [ -n "$rest" ]; do
		case "$rest" in
			*" "*) word="${rest%% *}"; rest="${rest#* }" ;;
			*) word="$rest"; rest="" ;;
		esac
		[ -z "$word" ] && continue
		while [ "${#word}" -gt "$max" ]; do
			if [ -n "$line" ] && [ "$line" != "  " ]; then
				printf '%s\n' "$line"
				line="  "
			fi
			n=$((max - ${#line}))
			printf '%s%s\n' "$line" "${word:0:$n}"
			word="${word:$n}"
			line="  "
		done
		if [ -z "$line" ]; then
			line="$word"
		elif [ "$line" = "  " ]; then
			line="  $word"
		elif [ $((${#line} + 1 + ${#word})) -le "$max" ]; then
			line="$line $word"
		else
			printf '%s\n' "$line"
			line="  $word"
		fi
	done

	n=$((GRADE_WIDTH - 2 - ${#line} - ${#label}))
	[ "$n" -lt 2 ] && n=2
	dots=""
	while [ "${#dots}" -lt "$n" ]; do
		dots="$dots."
	done

	# Test the terminal here, not in a $(...) subshell where stdout is a pipe.
	# LABCTL_COLOR (1 or 0), set by labctl for graders that run on a server
	# target over SSH, overrides the terminal test.
	colour=""
	if [ "${LABCTL_COLOR:-}" = 1 ] ||
		{ [ -z "${LABCTL_COLOR:-}" ] && [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; }; then
		case "$label" in
			PASS) colour=$'\033[32m' ;;
			FAIL) colour=$'\033[31m' ;;
			*) colour=$'\033[33m' ;;
		esac
		reset=$'\033[0m'
	fi
	printf '%s %s %s%s%s\n' "$line" "$dots" "$colour" "$label" "$reset"
}

criterion_result() {
	local text="$1" rc="${2:-1}"
	_GRADE_TOTAL=$((_GRADE_TOTAL + 1))
	if [ "$rc" = "0" ]; then
		_GRADE_PASSED=$((_GRADE_PASSED + 1))
		grade_line "$text" PASS
	else
		grade_line "$text" FAIL
	fi
	return 0
}

criterion() {
	local text="$1"
	shift
	if [ "$#" -gt 0 ] && "$@" </dev/null >/dev/null 2>&1; then
		criterion_result "$text" 0
	else
		criterion_result "$text" 1
	fi
	return 0
}

grade_begin() {
	local lab="${1:-lab}" host
	host=$(uname -n 2>/dev/null)
	host="${host%%.*}"
	grade_reset
	printf 'Grading %s on %s\n\n' "$lab" "${host:-localhost}"
}

grade_summary() {
	local label=FAIL rc=1
	if [ "$_GRADE_TOTAL" -gt 0 ] && [ "$_GRADE_PASSED" -eq "$_GRADE_TOTAL" ]; then
		label=PASS
		rc=0
	fi
	printf '\n'
	grade_line "Overall result" "$label"
	printf '%s of %s criteria met.\n' "$_GRADE_PASSED" "$_GRADE_TOTAL"
	return "$rc"
}

grade_end() {
	if grade_summary; then
		exit 0
	fi
	exit 1
}

grade_abort() {
	criterion_result "$1" 1
	grade_end
}

grade_require_state() {
	local lab="$1"
	local file="${2:-/opt/linux-labs/state/$lab}"
	if [ ! -r "$file" ]; then
		grade_abort "Lab was started with labctl start"
	fi
	return 0
}
