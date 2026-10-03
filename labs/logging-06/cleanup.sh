#!/bin/bash
# logging-06 cleanup: remove the drop-ins and the lab's persistent
# journal, then put back journald.conf, the drop-ins and the journal that
# existed before the lab, and restart journald.

STATE_DIR=/opt/linux-labs/state/logging-06
CONF=/etc/systemd/journald.conf
DROPIN_DIR=/etc/systemd/journald.conf.d
JDIR=/var/log/journal
BACKUP=/var/log/journal.logging-06-backup

# Never started: nothing to undo.
if [ ! -f "$STATE_DIR/journal" ]; then
	rm -rf "$STATE_DIR"
	exit 0
fi

if [ -f "$STATE_DIR/journald.conf" ] &&
	! cmp -s "$STATE_DIR/journald.conf" "$CONF"; then
	cp -p "$STATE_DIR/journald.conf" "$CONF"
	restorecon "$CONF" 2>/dev/null || true
fi

if [ -d "$DROPIN_DIR" ]; then
	find "$DROPIN_DIR" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
fi
if [ "$(cat "$STATE_DIR/dropin-dir" 2>/dev/null)" = existed ]; then
	mkdir -p "$DROPIN_DIR"
	find "$STATE_DIR/dropins" -mindepth 1 -maxdepth 1 \
		-exec mv -t "$DROPIN_DIR" {} + 2>/dev/null || true
	restorecon -R "$DROPIN_DIR" 2>/dev/null || true
else
	rmdir "$DROPIN_DIR" 2>/dev/null || true
fi

rm -rf "$JDIR"
if [ -d "$BACKUP" ]; then
	mv "$BACKUP" "$JDIR"
	restorecon -R "$JDIR" 2>/dev/null || true
fi
systemctl restart systemd-journald 2>/dev/null || true
# rsyslog's imjournal loses track of journal files that went away.
systemctl try-restart rsyslog 2>/dev/null || true
rm -rf "$STATE_DIR"
exit 0
