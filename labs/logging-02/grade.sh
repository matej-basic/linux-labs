#!/bin/bash
# logging-02 grader
source /opt/linux-labs/lib/grading.sh

RSYSLOG_CONF=/etc/rsyslog.d/myapp.conf
FAC_LOG=/var/log/myapp.log
PROG_LOG=/var/log/myapp-program.log
LR_CONF=/etc/logrotate.d/myapp

# Active lines of the logrotate configuration, without comments
lr_lines() {
	grep -Ev '^[[:space:]]*#' "$LR_CONF"
}

# Does the logrotate configuration contain this directive (extended regex)?
lr_has() {
	lr_lines | grep -Eq "$1"
}

conf_names_both_logs() {
	grep -Fq "$FAC_LOG" "$RSYSLOG_CONF" && grep -Fq "$PROG_LOG" "$RSYSLOG_CONF"
}

lr_covers_both() {
	local flat
	flat=$(lr_lines | tr '\n' ' ')
	grep -Eq "${FAC_LOG}[^{}]*\{" <<<"$flat" && grep -Eq "${PROG_LOG}[^{}]*\{" <<<"$flat"
}

lr_postrotate_signals_rsyslog() {
	lr_lines | sed -n '/^[[:space:]]*postrotate/,/^[[:space:]]*endscript/p' |
		grep -Eq 'rsyslog'
}

lr_syntax_ok() {
	local state rc
	state=$(mktemp) || return 1
	logrotate -d -s "$state" "$LR_CONF"
	rc=$?
	rm -f "$state"
	return $rc
}

mode_is_644() {
	[ "$(stat -c %a "$1" 2>/dev/null)" = 644 ]
}

grep_log() {
	grep -Fq "$2" "$1" 2>/dev/null
}

# Send one message per rule and wait up to 10 seconds for both to arrive
token="logging02-$$-$(date +%s)"
if systemctl is-active --quiet rsyslog; then
	logger -p local0.info -t myapp-facility "$token-facility"
	logger -p user.notice -t myapp "$token-program"
	for _ in 1 2 3 4 5 6 7 8 9 10; do
		grep -Fq "$token-facility" "$FAC_LOG" 2>/dev/null &&
			grep -Fq "$token-program" "$PROG_LOG" 2>/dev/null && break
		sleep 1
	done
fi

grade_begin logging-02

criterion "rsyslog is active" systemctl is-active --quiet rsyslog
criterion "$RSYSLOG_CONF names both log files" conf_names_both_logs
criterion "local0 messages are written to $FAC_LOG" grep_log "$FAC_LOG" "$token-facility"
criterion "Messages from program myapp go to $PROG_LOG" grep_log "$PROG_LOG" "$token-program"
criterion "File $FAC_LOG has mode 644" mode_is_644 "$FAC_LOG"
criterion "File $PROG_LOG has mode 644" mode_is_644 "$PROG_LOG"
criterion "$LR_CONF covers both log files" lr_covers_both
criterion "Logs rotate daily" lr_has '^[[:space:]]*daily[[:space:]]*$'
criterion "7 rotated logs are kept" lr_has '^[[:space:]]*rotate[[:space:]]+7[[:space:]]*$'
criterion "Rotated logs are compressed" lr_has '^[[:space:]]*compress[[:space:]]*$'
criterion "Empty log files are not rotated" lr_has '^[[:space:]]*notifempty[[:space:]]*$'
criterion "Missing log files are not an error" lr_has '^[[:space:]]*missingok[[:space:]]*$'
criterion "New logs are created as 644 root root" lr_has '^[[:space:]]*create[[:space:]]+0?644[[:space:]]+root[[:space:]]+(root|0)[[:space:]]*$'
criterion "rsyslog is signalled after rotation" lr_postrotate_signals_rsyslog
criterion "logrotate accepts $LR_CONF" lr_syntax_ok

grade_end
