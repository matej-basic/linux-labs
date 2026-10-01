#!/bin/bash
# logging-03 grader
source /opt/linux-labs/lib/grading.sh

JDIR=/var/log/journal
UNIT=/etc/systemd/system/labtest-fail.service

journal_dir_ok() {
	[ -d "$JDIR" ] || return 1
	[ "$(stat -c %U "$JDIR")" = root ] || return 1
	local mode
	mode=$(stat -c %A "$JDIR")
	# no write bit for group or others (setgid from journald is fine)
	[ "${mode:5:1}" != w ] && [ "${mode:8:1}" != w ]
}

journal_file_written() {
	compgen -G "$JDIR/*/system.journal" >/dev/null
}

unit_has() {
	grep -Eq "$1" "$UNIT"
}

grade_begin logging-03

criterion "Directory /var/log/journal is owned by root, not writable" journal_dir_ok
criterion "journald writes a journal file below /var/log/journal" journal_file_written
criterion "Unit file labtest-fail.service exists" test -f "$UNIT"
criterion "Unit description is Lab Test Fail Service" \
	unit_has '^Description=Lab Test Fail Service[[:space:]]*$'
criterion "Unit type is simple" unit_has '^Type=simple[[:space:]]*$'
criterion "Unit runs /bin/false" \
	unit_has '^ExecStart=[[:space:]]*/(usr/)?bin/false[[:space:]]*$'
criterion "Unit is wanted by multi-user.target" \
	unit_has '^WantedBy=multi-user\.target[[:space:]]*$'
criterion "labtest-fail.service is in the failed state" \
	systemctl is-failed --quiet labtest-fail.service
criterion "systemd-journald is active" systemctl is-active --quiet systemd-journald
grade_end
