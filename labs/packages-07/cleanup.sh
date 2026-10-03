#!/bin/bash
# packages-07 cleanup: put /etc/chrony.conf back exactly as it was at
# the first start, remove the chrony .rpmnew and .rpmsave files the lab
# or the solution left (and put back any that existed at the first
# start), give chronyd its recorded boot and running state, then
# restore the package set (pkg_restore removes mc and gpm-libs if they
# are still there). When the package set cannot be restored, the
# records stay for the next reset and the exit status is 1.
source /opt/linux-labs/lib/packages.sh

LAB=packages-07
STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/$LAB"
REC_DIR="$STATE_DIR/$LAB.d"
CONF=/etc/chrony.conf

rc=0
rm -f /root/chrony.conf.old
rm -rf "$REC_DIR.tmp"

if [ -d "$REC_DIR" ]; then
	if [ -f "$REC_DIR/chrony.conf.orig" ]; then
		rm -f "$CONF"
		cp -a "$REC_DIR/chrony.conf.orig" "$CONF" || rc=1
	fi
	find /etc \( -name 'chrony*.rpmnew' -o -name 'chrony*.rpmsave' \) \
		-exec rm -f {} + 2>/dev/null
	while IFS= read -r f; do
		[ -n "$f" ] || continue
		cp -a "$REC_DIR/leftovers/$(printf '%s' "$f" | tr / _)" "$f" || rc=1
	done < "$REC_DIR/leftovers.list"
	restorecon "$CONF" >/dev/null 2>&1

	systemctl reset-failed chronyd >/dev/null 2>&1
	if grep -qx chronyd-enabled "$REC_DIR/flags" 2>/dev/null; then
		systemctl enable chronyd >/dev/null 2>&1
	else
		systemctl disable chronyd >/dev/null 2>&1
	fi
	if grep -qx chronyd-active "$REC_DIR/flags" 2>/dev/null; then
		systemctl restart chronyd >/dev/null 2>&1 || {
			echo "Error: chronyd does not start with the restored $CONF." >&2
			rc=1
		}
	else
		systemctl stop chronyd >/dev/null 2>&1
	fi
fi

pkg_restore "$LAB" || rc=1

if [ "$rc" -eq 0 ]; then
	rm -rf "$REC_DIR"
	rm -f "$STATE_FILE" "$STATE_FILE.tmp"
fi
exit "$rc"
