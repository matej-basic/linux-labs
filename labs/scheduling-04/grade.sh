#!/bin/bash
# scheduling-04 grader
source /opt/linux-labs/lib/grading.sh

LAB=scheduling-04
STATE_DIR=/opt/linux-labs/state/$LAB

grade_begin scheduling-04
grade_require_state scheduling-04 "$STATE_DIR/owner"
owner=$(head -n 1 "$STATE_DIR/owner")
home=$(getent passwd "$owner" | cut -d: -f6)
report="$home/disk-report.txt"

# Ids of the owner's jobs that run at 23:30 on 31 December (any year)
year_end_jobs() {
	LC_ALL=C atq 2>/dev/null | awk -v u="$owner" '
		$NF == u && $3 == "Dec" && $4 + 0 == 31 && $5 ~ /^23:30(:00)?$/ { print $1 }'
}

has_year_end_job() {
	[ -n "$(year_end_jobs)" ]
}

# The commands of a job: the lines after the here-document line that at
# writes after the saved environment
job_commands() {
	at -c "$1" 2>/dev/null | awk '
		f && /^marcinDELIMITER/ { exit }
		f { print }
		/<< *.marcinDELIMITER/ { f = 1 }'
}

# One command line runs df -h and writes to the report file
job_writes_report() {
	local id
	for id in $(year_end_jobs); do
		job_commands "$id" | awk -v p="$report" '
			index($0, "df -h") && ($0 ~ />/ || $0 ~ /tee/) &&
			(index($0, p) || index($0, "~/disk-report.txt") ||
			 index($0, "$HOME/disk-report.txt") ||
			 index($0, "${HOME}/disk-report.txt")) { f = 1 }
			END { exit !f }' && return 0
	done
	return 1
}

# /etc/at.allow lists exactly root, the owner and reporter
at_allow_exact() {
	local want got
	[ -f /etc/at.allow ] || return 1
	want=$(printf '%s\n' root "$owner" reporter | sort -u)
	got=$(awk 'NF { print $1 }' /etc/at.allow | sort -u)
	[ "$want" = "$got" ] && [ "$(awk 'NF' /etc/at.allow | awk 'NF != 1' | wc -l)" -eq 0 ]
}

can_use_at() {
	command -v at >/dev/null 2>&1 || return 1
	runuser -u "$1" -- at -l </dev/null >/dev/null 2>&1
}

reporter_can_use_at() { can_use_at reporter; }

intern_denied() {
	id intern &>/dev/null || return 1
	command -v at >/dev/null 2>&1 || return 1
	runuser -u intern -- at -l </dev/null 2>&1 | grep -qi 'permission'
}

bashrc_sets_umask() {
	grep -Eq '^[[:space:]]*umask[[:space:]]+0?027([[:space:]]*(;|#|$))' "$home/.bashrc" 2>/dev/null
}

login_umask() {
	[ "$(runuser -l "$owner" -c umask </dev/null 2>/dev/null | tail -n 1)" = 0027 ]
}

# Mode of a new file (f) or directory (d) made in a login shell of the owner
new_mode() {
	local dir mode
	dir=$(mktemp -d) || return 1
	chown "$owner" "$dir"
	chmod 700 "$dir"
	if [ "$1" = f ]; then
		runuser -l "$owner" -c "touch $dir/new" </dev/null >/dev/null 2>&1
	else
		runuser -l "$owner" -c "mkdir $dir/new" </dev/null >/dev/null 2>&1
	fi
	mode=$(stat -c %a "$dir/new" 2>/dev/null)
	rm -rf "$dir"
	[ "$mode" = "$2" ]
}
new_file_640() { new_mode f 640; }
new_dir_750() { new_mode d 750; }

criterion "Service atd is enabled" systemctl is-enabled --quiet atd.service
criterion "Service atd is running" systemctl is-active --quiet atd.service
criterion "$owner has an at job for 23:30 on 31 December" has_year_end_job
criterion "The job writes df -h output to $report" job_writes_report
criterion "/etc/at.allow lists exactly root, $owner and reporter" at_allow_exact
criterion "User reporter can use at" reporter_can_use_at
criterion "User intern cannot use at" intern_denied
criterion "File $home/.bashrc sets umask 027" bashrc_sets_umask
criterion "A login shell of $owner has umask 0027" login_umask
criterion "New files of $owner get mode 640" new_file_640
criterion "New directories of $owner get mode 750" new_dir_750
grade_end
