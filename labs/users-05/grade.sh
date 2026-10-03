#!/bin/bash
# users-05 grader
source /opt/linux-labs/lib/grading.sh

STATE=/opt/linux-labs/state/users-05/state
DROPIN=/etc/sudoers.d/50-lab
ALIAS=HTTPD_CMDS
RESTART=(/usr/bin/systemctl restart httpd)
STATUS=(/usr/bin/systemctl status httpd)
JOURNAL=/usr/bin/journalctl

grade_begin users-05
grade_require_state users-05 "$STATE"

# The drop-in file as logical lines: continuation lines joined, comments
# and blank lines removed
dropin_lines() {
	[ -f "$DROPIN" ] || return 0
	awk '
		{ line = line $0 }
		/\\$/ { sub(/\\$/, "", line); next }
		{
			sub(/^[[:space:]]+/, "", line)
			if (line !~ /^#/ && line != "") print line
			line = ""
		}
	' "$DROPIN"
}

owner_mode_ok() {
	[ "$(stat -c '%U:%G %a' "$DROPIN" 2>/dev/null)" = "root:root 440" ]
}

alias_defined() {
	dropin_lines | grep -Eq "^Cmnd_Alias[[:space:]]+${ALIAS}[[:space:]]*="
}

group_rule_uses_alias() {
	dropin_lines | grep -Eq "^%helpdesk[[:space:]].*[=:,[:space:]]${ALIAS}([[:space:],]|$)"
}

# allowed <user> <runas> <command...>: sudo lists the command for the user
allowed() {
	local user=$1 runas=$2
	shift 2
	sudo -l -U "$user" -u "$runas" "$@" >/dev/null 2>&1
}

# runs_without_password <user> <command...>: sudo -n runs the command
# for the user without asking for a password
runs_without_password() {
	local user=$1 out
	shift
	allowed "$user" root "$@" || return 1
	out=$(cd / && runuser -u "$user" -- sudo -n "$@" 2>&1 </dev/null)
	! printf '%s\n' "$out" | grep -q 'sudo: a password is required'
}

webops_restart() { allowed webops root "${RESTART[@]}"; }
webops_status() { allowed webops root "${STATUS[@]}"; }

webops_nopasswd() {
	runs_without_password webops "${STATUS[@]}" &&
		runs_without_password webops "${RESTART[@]}"
}

webops_nothing_else() {
	! allowed webops root /usr/bin/systemctl stop httpd &&
		! allowed webops root /usr/bin/systemctl restart sshd &&
		! allowed webops root /usr/bin/systemctl status sshd &&
		! allowed webops root /usr/bin/cat /etc/shadow &&
		! allowed webops root /usr/bin/bash &&
		! allowed webops root "$JOURNAL" &&
		! allowed webops daemon "${STATUS[@]}" &&
		! allowed webops auditor "${STATUS[@]}"
}

auditor_journal() {
	allowed auditor root "$JOURNAL" &&
		allowed auditor root "$JOURNAL" -u sshd
}

auditor_password() {
	local out
	allowed auditor root "$JOURNAL" || return 1
	(cd / && runuser -u auditor -- sudo -K) >/dev/null 2>&1
	out=$(cd / && runuser -u auditor -- sudo -n "$JOURNAL" -n 0 2>&1 </dev/null)
	printf '%s\n' "$out" | grep -q 'sudo: a password is required'
}

auditor_nothing_else() {
	! allowed auditor root /usr/bin/cat /etc/shadow &&
		! allowed auditor root /usr/bin/bash &&
		! allowed auditor root "${STATUS[@]}" &&
		! allowed auditor root /usr/bin/systemctl restart sshd &&
		! allowed auditor daemon "$JOURNAL" &&
		! allowed auditor webops "$JOURNAL"
}

criterion "File $DROPIN exists" test -f "$DROPIN"
criterion "File 50-lab is owned by root:root with mode 0440" owner_mode_ok
criterion "visudo -c reports no errors" visudo -c
criterion "50-lab defines the command alias $ALIAS" alias_defined
criterion "50-lab has a rule for group helpdesk that uses $ALIAS" group_rule_uses_alias
criterion "webops may run systemctl restart httpd as root" webops_restart
criterion "webops may run systemctl status httpd as root" webops_status
criterion "webops runs both httpd commands without a password" webops_nopasswd
criterion "webops may run no other command and as no other user" webops_nothing_else
criterion "auditor may run journalctl with any options as root" auditor_journal
criterion "auditor must enter a password to run journalctl" auditor_password
criterion "auditor may run no other command and as no other user" auditor_nothing_else
grade_end
