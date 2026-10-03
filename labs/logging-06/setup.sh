#!/bin/bash
# logging-06 setup: journald with the shipped configuration only, no
# drop-in files and a volatile journal (no /var/log/journal). On the
# first start the lab records /etc/systemd/journald.conf, moves existing
# drop-ins into the state directory and moves an existing persistent
# journal aside; cleanup.sh puts all of it back. Prints nothing on
# success.
set -eu

STATE_DIR=/opt/linux-labs/state/logging-06
CONF=/etc/systemd/journald.conf
DROPIN_DIR=/etc/systemd/journald.conf.d
JDIR=/var/log/journal
BACKUP=/var/log/journal.logging-06-backup

if [ ! -f "$CONF" ]; then
	echo "Error: $CONF does not exist." >&2
	exit 1
fi

# Record the starting state only on the first start, so that a second
# start never overwrites it.
if [ ! -f "$STATE_DIR/journal" ]; then
	mkdir -p "$STATE_DIR/dropins"
	cp -p "$CONF" "$STATE_DIR/journald.conf"
	if [ -d "$DROPIN_DIR" ]; then
		echo existed > "$STATE_DIR/dropin-dir"
		find "$DROPIN_DIR" -mindepth 1 -maxdepth 1 \
			-exec mv -t "$STATE_DIR/dropins" {} +
	else
		echo absent > "$STATE_DIR/dropin-dir"
	fi
	if [ -d "$JDIR" ] && [ ! -e "$BACKUP" ]; then
		mv "$JDIR" "$BACKUP"
		echo backup > "$STATE_DIR/journal"
	else
		echo none > "$STATE_DIR/journal"
	fi
	chmod 755 "$STATE_DIR" "$STATE_DIR/dropins"
	chmod 644 "$STATE_DIR/dropin-dir" "$STATE_DIR/journal"
fi

# Back to the recorded journald.conf and no drop-ins.
if ! cmp -s "$STATE_DIR/journald.conf" "$CONF"; then
	cp -p "$STATE_DIR/journald.conf" "$CONF"
	restorecon "$CONF" 2>/dev/null || true
fi
if [ -d "$DROPIN_DIR" ]; then
	find "$DROPIN_DIR" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
	if [ "$(cat "$STATE_DIR/dropin-dir")" = absent ]; then
		rmdir "$DROPIN_DIR"
	fi
fi

# Volatile journal: journald keeps the old files open until it
# restarts, so restart it after removing the directory. rsyslog reads
# the journal through imjournal and loses track of it when the files
# go away, so restart it as well (only when it runs).
rm -rf "$JDIR"
systemctl restart systemd-journald
systemctl try-restart rsyslog
