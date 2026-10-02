#!/bin/bash
# logging-04 cleanup: puts the audit configuration back as it was before
# the lab (auditd.conf, audit.rules, the directory rules.d), makes auditd
# read auditd.conf again with a signal and loads exactly the rules that
# were loaded at the start. Then removes /etc/lab-app.conf and the state.
#
# auditd is never stopped or restarted. The loaded rules are restored
# from the copy that setup.sh made with auditctl -l, not with augenrules,
# so rules that were loaded without a rules file stay as they were.

LAB=logging-04
STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/$LAB"
BACKUP_DIR="$STATE_DIR/$LAB.d"
AUDIT_DIR=/etc/audit

state_value() {
	[ -r "$STATE_FILE" ] || return 0
	sed -n "s/^$1=//p" "$STATE_FILE" | head -n 1
}

# reload_auditd: make the running auditd read auditd.conf again
reload_auditd() {
	auditctl --signal reload >/dev/null 2>&1 && return 0
	pkill -HUP -x auditd >/dev/null 2>&1
}

rc=0

if [ -f "$STATE_FILE" ] && [ -d "$BACKUP_DIR" ]; then
	# 1. auditd.conf, and auditd reads it again
	if [ -f "$BACKUP_DIR/auditd.conf" ]; then
		cp -a "$BACKUP_DIR/auditd.conf" "$AUDIT_DIR/auditd.conf"
		if systemctl is-active --quiet auditd; then
			reload_auditd || {
				echo "Error: auditd did not reload auditd.conf." >&2
				rc=1
			}
		fi
	fi

	# 2. Rules files: rules.d, audit.rules and audit.rules.prev
	if [ -d "$BACKUP_DIR/rules.d" ]; then
		rm -rf "$AUDIT_DIR/rules.d"
		cp -a "$BACKUP_DIR/rules.d" "$AUDIT_DIR/rules.d"
	fi
	if [ "$(state_value rules_file)" = 1 ] && [ -f "$BACKUP_DIR/audit.rules" ]; then
		cp -a "$BACKUP_DIR/audit.rules" "$AUDIT_DIR/audit.rules"
	elif [ "$(state_value rules_file)" = 0 ]; then
		rm -f "$AUDIT_DIR/audit.rules"
	fi
	if [ "$(state_value rules_prev)" = 1 ] && [ -f "$BACKUP_DIR/audit.rules.prev" ]; then
		cp -a "$BACKUP_DIR/audit.rules.prev" "$AUDIT_DIR/audit.rules.prev"
	else
		rm -f "$AUDIT_DIR/audit.rules.prev"
	fi
	restorecon -R "$AUDIT_DIR" >/dev/null 2>&1

	# 3. Loaded rules: exactly the set from the start of the lab
	if auditctl -s 2>/dev/null | grep -qE '^enabled 2$'; then
		echo "Error: the audit rules are immutable; reboot to remove the lab rules." >&2
		rc=1
	elif [ -f "$BACKUP_DIR/loaded.rules" ]; then
		auditctl -D >/dev/null 2>&1
		if ! grep -qx 'No rules' "$BACKUP_DIR/loaded.rules"; then
			auditctl -R "$BACKUP_DIR/loaded.rules" >/dev/null 2>&1 || {
				echo "Error: the audit rules from before the lab did not load." >&2
				rc=1
			}
		fi
	fi
else
	# Lab not started: only the rules with the lab keys
	auditctl -D -k lab_config >/dev/null 2>&1
	auditctl -D -k lab_delete >/dev/null 2>&1
fi

# 4. Lab files
rm -f /etc/lab-app.conf
rm -f /tmp/logging-04-grade.*

if [ "$rc" -eq 0 ]; then
	rm -rf "$BACKUP_DIR"
	rm -f "$STATE_FILE"
fi
exit "$rc"
