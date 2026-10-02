#!/bin/bash
# logging-04 grader: checks the rules file, the compiled audit.rules, the
# loaded rules (auditctl -l), auditd.conf and that auditd read it, then
# creates real events and looks for them with ausearch. Only events from
# this grading run count: they carry a timestamp after its start, and
# the deleted test files have new random names.
#
# Events: a write and a mode change on /etc/lab-app.conf (as root), and
# the deletion of three files in /tmp: as the task user with the task
# user's login UID, and as root with the login UID 0 and with no login
# UID. Each runs in a subshell that sets its own login UID, so the
# grader's own session keeps its value.
source /opt/linux-labs/lib/grading.sh

LAB=logging-04
STATE_FILE=/opt/linux-labs/state/$LAB
AUDIT_DIR=/etc/audit
LAB_RULES=$AUDIT_DIR/rules.d/lab-audit.rules
APP_CONF=/etc/lab-app.conf

grade_begin logging-04
grade_require_state logging-04 "$STATE_FILE"

owner=$(sed -n 's/^owner=//p' "$STATE_FILE" | head -n 1)
uid=$(id -u "$owner" 2>/dev/null)

# ausearch reads standard input when it is not a terminal; --input-logs
# makes it read the log files instead
asearch() {
	ausearch --input-logs "$@" 2>/dev/null
}

# since <epoch>: true when the raw records on stdin of the requested
# type include one with a timestamp at or after <epoch>
since() {
	awk -v s="$1" -v t="${2:-SYSCALL}" '
		$1 == "type=" t {
			ts = $2
			sub(/^msg=audit\(/, "", ts)
			sub(/[.:].*/, "", ts)
			if (ts + 0 >= s) f = 1
		}
		END { exit !f }'
}

# conf_value <key>: the last value of <key> in auditd.conf
conf_value() {
	awk -F= -v k="$1" '
		/^[[:space:]]*#/ { next }
		{
			key = $1; gsub(/[[:space:]]/, "", key)
			if (key == k) { v = $2; gsub(/[[:space:]]/, "", v); val = v }
		}
		END { print tolower(val) }' "$AUDIT_DIR/auditd.conf" 2>/dev/null
}

auditd_running() {
	systemctl is-active --quiet auditd && systemctl is-enabled --quiet auditd
}

# has_key <file> <key>: a rule line (not a comment) with the key
has_key() {
	grep -Eq "^[^#]*(-k[[:space:]]+|-F[[:space:]]+key=)$2([[:space:]]|\$)" "$1"
}

rules_file_ok() {
	[ -f "$LAB_RULES" ] && has_key "$LAB_RULES" lab_config &&
		has_key "$LAB_RULES" lab_delete
}

compiled_ok() {
	[ -f "$AUDIT_DIR/audit.rules" ] || return 1
	has_key "$AUDIT_DIR/audit.rules" lab_config || return 1
	has_key "$AUDIT_DIR/audit.rules" lab_delete || return 1
	augenrules --check 2>&1 | grep -q 'No change'
}

# The watch, as -w ... -p ... -k ... or as a path rule with perm=
watch_loaded() {
	auditctl -l 2>/dev/null | awk -v p="$APP_CONF" '
		{
			path = ""; perm = ""; key = ""
			for (i = 1; i <= NF; i++) {
				if ($i == "-w") path = $(i + 1)
				if ($i == "-p") perm = $(i + 1)
				if ($i == "-k") key = $(i + 1)
				if ($i ~ /^path=/) path = substr($i, 6)
				if ($i ~ /^perm=/) perm = substr($i, 6)
				if ($i ~ /^key=/) key = substr($i, 5)
			}
			if (path == p && key == "lab_config" && perm ~ /w/ && perm ~ /a/) f = 1
		}
		END { exit !f }'
}

delete_rule_loaded() {
	auditctl -l 2>/dev/null | awk '
		{
			act = ""; arch = ""; key = ""; ge = 0; set = 0; sc = ","
			for (i = 1; i <= NF; i++) {
				if ($i == "-a") act = $(i + 1)
				if ($i == "-S") sc = sc $(i + 1) ","
				if ($i == "-k") key = $(i + 1)
				if ($i ~ /^key=/) key = substr($i, 5)
				if ($i ~ /^arch=/) arch = substr($i, 6)
				if ($i == "auid>=1000") ge = 1
				if ($i ~ /^auid!=(-1|4294967295|unset)$/) set = 1
			}
			if ((act == "always,exit" || act == "exit,always") &&
			    arch == "b64" && key == "lab_delete" && ge && set &&
			    sc ~ /,unlink,/ && sc ~ /,unlinkat,/ &&
			    sc ~ /,rename,/ && sc ~ /,renameat,/) f = 1
		}
		END { exit !f }'
}

auditd_reloaded() {
	local m
	m=$(stat -c %Y "$AUDIT_DIR/auditd.conf" 2>/dev/null) || return 1
	asearch --raw -m DAEMON_CONFIG | since "$m" DAEMON_CONFIG && return 0
	asearch --raw -m DAEMON_START | since "$m" DAEMON_START
}

# --- Real events -------------------------------------------------------

start=$(date +%s)
user_file=""
root_file=""
unset_file=""

# Write (open for writing, content unchanged) and a mode change to the
# same mode on the watched file
if [ -f "$APP_CONF" ]; then
	mode=$(stat -c %a "$APP_CONF")
	printf '' >> "$APP_CONF"
	chmod "$mode" "$APP_CONF"
fi

# del_as <login UID> <user> <file>: delete <file> as <user> with that
# login UID (the shell's own login UID when it cannot be set)
del_as() {
	(
		echo "$1" > /proc/self/loginuid 2>/dev/null
		runuser -u "$2" -- rm -f "$3"
	) </dev/null >/dev/null 2>&1
}

# Root without and with the login UID 0 first, then the task user
unset_file=$(mktemp /tmp/logging-04-grade.XXXXXXXX) &&
	del_as 4294967295 root "$unset_file"
root_file=$(mktemp /tmp/logging-04-grade.XXXXXXXX) &&
	del_as 0 root "$root_file"
if [ -n "$uid" ]; then
	user_file=$(mktemp /tmp/logging-04-grade.XXXXXXXX) &&
		chown "$owner" "$user_file" &&
		del_as "$uid" "$owner" "$user_file"
fi
rm -f "$unset_file" "$root_file" "$user_file"

# event <key> <path> [<syscall>...]: an event of this run for the path
# with the key, by one of the system calls if given
event() {
	local key=$1 path=$2 sc
	shift 2
	[ -n "$path" ] || return 1
	if [ $# -eq 0 ]; then
		asearch -ts recent --raw -k "$key" -f "$path" | since "$start"
		return
	fi
	for sc in "$@"; do
		asearch -ts recent --raw -k "$key" -f "$path" -sc "$sc" |
			since "$start" && return 0
	done
	return 1
}

# auditd writes the events with a short delay: wait for the last one
for _ in 1 2 3 4 5 6 7 8 9 10; do
	event lab_delete "$user_file" && break
	sleep 1
done

write_recorded() {
	event lab_config "$APP_CONF" openat open
}

attr_recorded() {
	event lab_config "$APP_CONF" fchmodat chmod fchmod
}

user_delete_recorded() {
	event lab_delete "$user_file"
}

root_delete_not_recorded() {
	! event lab_delete "$root_file" && ! event lab_delete "$unset_file"
}

# --- Criteria ----------------------------------------------------------

criterion "auditd is enabled and running" auditd_running
criterion "$LAB_RULES has the rules for both keys" rules_file_ok
criterion "audit.rules is generated from rules.d and up to date" compiled_ok
criterion "Watch on $APP_CONF with key lab_config is loaded" watch_loaded
criterion "Deletion rule with key lab_delete is loaded" delete_rule_loaded
criterion "A write to $APP_CONF is recorded" write_recorded
criterion "A mode change of $APP_CONF is recorded" attr_recorded
criterion "A deletion by $owner is recorded" user_delete_recorded
criterion "Deletions without a regular login UID are not recorded" root_delete_not_recorded

rc=1
[ "$(conf_value max_log_file)" = 25 ] && rc=0
criterion_result "auditd.conf sets max_log_file to 25" "$rc"
rc=1
[ "$(conf_value max_log_file_action)" = keep_logs ] && rc=0
criterion_result "auditd.conf sets max_log_file_action to keep_logs" "$rc"
criterion "auditd has read auditd.conf since its last change" auditd_reloaded
grade_end
