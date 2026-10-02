#!/bin/bash
# users-02 setup: no contractors group, no dave and eve, no limits file,
# and the original login.defs aging values recorded for cleanup.
# Prints nothing on success.
set -eu

STATE_FILE=/opt/linux-labs/state/users-02
LIMITS=/etc/security/limits.d/70-contractors.conf
KEYS="PASS_MAX_DAYS PASS_MIN_DAYS PASS_WARN_AGE"
BACKUP=/var/tmp/users-02.login.defs.pre

# Last active value of a login.defs key (empty if not set)
get_key() {
	awk -v k="$1" '$1 == k { v = $2 } END { print v }' /etc/login.defs
}

# Set a login.defs key to a value; an empty value removes the key
set_key() {
	local key=$1 val=$2
	sed -i -E "/^[[:space:]]*${key}[[:space:]]/d" /etc/login.defs
	if [ -n "$val" ]; then
		printf '%s\t%s\n' "$key" "$val" >> /etc/login.defs
	fi
}

if [ ! -f "$STATE_FILE" ]; then
	# First start: refuse to touch accounts that this lab did not create
	for u in dave eve; do
		if getent passwd "$u" >/dev/null; then
			echo "Error: user $u already exists and was not created by this lab." >&2
			exit 1
		fi
	done
	if getent group contractors >/dev/null; then
		echo "Error: group contractors already exists." >&2
		exit 1
	fi
	if [ -e "$LIMITS" ]; then
		echo "Error: $LIMITS already exists." >&2
		exit 1
	fi
	mkdir -p "$(dirname "$STATE_FILE")"
	for k in $KEYS; do
		echo "$k=$(get_key "$k")"
	done > "$STATE_FILE"
	chmod 644 "$STATE_FILE"
	cp -p /etc/login.defs "$BACKUP"
else
	# Restart: remove what a previous run or its solution created
	for u in dave eve; do
		if getent passwd "$u" >/dev/null; then
			userdel -r -f "$u" >/dev/null 2>&1 || true
		fi
	done
	groupdel contractors >/dev/null 2>&1 || true
	rm -f "$LIMITS"
	# Put login.defs back exactly as it was before the first start
	if [ -f "$BACKUP" ]; then
		cp -p "$BACKUP" /etc/login.defs
	else
		for k in $KEYS; do
			set_key "$k" "$(sed -n "s/^$k=//p" "$STATE_FILE")"
		done
	fi
fi

exit 0
