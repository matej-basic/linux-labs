#!/bin/bash
# logging-04 setup: the watched file /etc/lab-app.conf and copies of the
# audit configuration as it is now (auditd.conf, audit.rules, the
# directory rules.d and the rules loaded in the kernel), so cleanup.sh
# can put back exactly what was there. Prints nothing on success.
#
# setup never stops auditd and never changes rules that existed before.
set -eu

LAB=logging-04
STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/$LAB"
BACKUP_DIR="$STATE_DIR/$LAB.d"
AUDIT_DIR=/etc/audit
LAB_RULES="$AUDIT_DIR/rules.d/lab-audit.rules"
APP_CONF=/etc/lab-app.conf

# Restart: undo the previous run (and its solution) first, so the copies
# below are the configuration from before the lab
if [ -f "$STATE_FILE" ]; then
	bash "$(dirname "$0")/cleanup.sh"
fi

for c in auditctl augenrules ausearch; do
	if ! command -v "$c" >/dev/null 2>&1; then
		echo "Error: $c is not installed (package audit)." >&2
		exit 1
	fi
done
if ! systemctl is-active --quiet auditd; then
	echo "Error: auditd is not running." >&2
	exit 1
fi
if auditctl -s 2>/dev/null | grep -qE '^enabled 2$'; then
	echo "Error: the audit rules are immutable (enabled 2); reboot first." >&2
	exit 1
fi
if [ ! -f "$AUDIT_DIR/auditd.conf" ] || [ ! -d "$AUDIT_DIR/rules.d" ]; then
	echo "Error: $AUDIT_DIR/auditd.conf or $AUDIT_DIR/rules.d is missing." >&2
	exit 1
fi

# Task user: LAB_USER from labctl, else the first regular user
owner="${LAB_USER:-student}"
if ! id "$owner" &>/dev/null; then
	owner=$(getent passwd | awk -F: '$3 >= 1000 && $3 < 60000 { print $1; exit }')
fi
if [ -z "$owner" ] || ! id "$owner" &>/dev/null; then
	echo "Error: no regular user account found for the lab." >&2
	exit 1
fi

# Leftovers of an earlier run without a state file: the lab's rules file
# and the rules with the lab keys
if [ -e "$LAB_RULES" ]; then
	rm -f "$LAB_RULES"
	augenrules >/dev/null 2>&1 || true
fi
auditctl -D -k lab_config >/dev/null 2>&1 || true
auditctl -D -k lab_delete >/dev/null 2>&1 || true
rm -f /tmp/logging-04-grade.*

# Copies of the audit configuration
mkdir -p "$STATE_DIR"
rm -rf "$BACKUP_DIR"
mkdir -m 700 "$BACKUP_DIR"
cp -a "$AUDIT_DIR/auditd.conf" "$BACKUP_DIR/auditd.conf"
cp -a "$AUDIT_DIR/rules.d" "$BACKUP_DIR/rules.d"
rules_file=0
if [ -f "$AUDIT_DIR/audit.rules" ]; then
	rules_file=1
	cp -a "$AUDIT_DIR/audit.rules" "$BACKUP_DIR/audit.rules"
fi
rules_prev=0
if [ -f "$AUDIT_DIR/audit.rules.prev" ]; then
	rules_prev=1
	cp -a "$AUDIT_DIR/audit.rules.prev" "$BACKUP_DIR/audit.rules.prev"
fi
auditctl -l > "$BACKUP_DIR/loaded.rules"

{
	echo "owner=$owner"
	echo "rules_file=$rules_file"
	echo "rules_prev=$rules_prev"
} > "$STATE_FILE"
chmod 644 "$STATE_FILE"

# The application configuration file the watch is for
cat > "$APP_CONF" <<'CONF'
# lab-app configuration (logging-04)
listen_port = 8080
log_level = info
data_dir = /var/lib/lab-app
CONF
chmod 644 "$APP_CONF"
chown root:root "$APP_CONF"
restorecon "$APP_CONF" 2>/dev/null || true

exit 0
