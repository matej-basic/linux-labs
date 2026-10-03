#!/bin/bash
# systemd-08 cleanup: remove labapp, its overrides, the vendor unit, the
# program and the state file.
UNIT=labapp.service

systemctl stop "$UNIT" >/dev/null 2>&1 || true
systemctl disable "$UNIT" >/dev/null 2>&1 || true
rm -rf "/etc/systemd/system/$UNIT" "/etc/systemd/system/$UNIT.d" \
	"/run/systemd/system/$UNIT" "/run/systemd/system/$UNIT.d" \
	"/etc/systemd/system/multi-user.target.wants/$UNIT" \
	"/usr/lib/systemd/system/$UNIT" /usr/local/libexec/labapp \
	/opt/linux-labs/state/systemd-08
systemctl daemon-reload >/dev/null 2>&1 || true
systemctl reset-failed "$UNIT" >/dev/null 2>&1 || true
exit 0
