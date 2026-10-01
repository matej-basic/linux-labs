#!/bin/bash
# scheduling-01 grader
source /opt/linux-labs/lib/grading.sh

grade_begin scheduling-01

# Active (non-comment) lines of the root crontab that mention the text
job_lines() {
	crontab -u root -l 2>/dev/null | grep -v '^[[:space:]]*#' | grep -F 'Daily task executed'
}

job_exists() {
	[ -n "$(job_lines)" ]
}

# Minute 0, hour 2, every day of month, month and weekday
scheduled_daily_at_two() {
	job_lines | awk '$1 ~ /^0+$/ && $2 ~ /^0?2$/ && $3 == "*" && $4 == "*" && $5 == "*" { f = 1 } END { exit !f }'
}

appends_to_log() {
	job_lines | grep -Eq 'Daily task executed.*>>[[:space:]]*/var/log/daily-task\.log([[:space:]]|$)'
}

criterion "Root crontab has an entry for Daily task executed" job_exists
criterion "Entry is scheduled daily at 2:00" scheduled_daily_at_two
criterion "Entry appends to /var/log/daily-task.log" appends_to_log
grade_end
