#!/bin/bash
# systemd-08 setup: install the vendor-style unit labapp.service and its
# program, disabled and stopped, with no local overrides. Record the
# checksum of the vendor unit for the grader. Prints nothing on success.
set -eu

UNIT=labapp.service
VENDOR=/usr/lib/systemd/system/$UNIT
PROG=/usr/local/libexec/labapp
STATE_DIR=/opt/linux-labs/state
STATE_FILE=$STATE_DIR/systemd-08

# Remove what an earlier run or the solution left behind
systemctl stop "$UNIT" >/dev/null 2>&1 || true
systemctl disable "$UNIT" >/dev/null 2>&1 || true
rm -rf "/etc/systemd/system/$UNIT" "/etc/systemd/system/$UNIT.d" \
	"/run/systemd/system/$UNIT" "/run/systemd/system/$UNIT.d" \
	"/etc/systemd/system/multi-user.target.wants/$UNIT"

# The program: logs its mode once, then idles
mkdir -p /usr/local/libexec
cat > "$PROG" <<'PROGRAM'
#!/bin/bash
# labapp: a small demo service for the systemd-08 lab
echo "labapp starting in mode ${LAB_MODE:-unset}"
while true; do
	sleep 30
done
PROGRAM
chmod 0755 "$PROG"
restorecon "$PROG" >/dev/null 2>&1 || true

# The vendor unit, as a package would ship it
cat > "$VENDOR" <<'UNITFILE'
[Unit]
Description=Lab demo application
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/libexec/labapp
Environment=LAB_MODE=development
Restart=no

[Install]
WantedBy=multi-user.target
UNITFILE
chmod 0644 "$VENDOR"
restorecon "$VENDOR" >/dev/null 2>&1 || true

systemctl daemon-reload
systemctl reset-failed "$UNIT" >/dev/null 2>&1 || true

mkdir -p "$STATE_DIR"
sha256sum "$VENDOR" | awk '{ print $1 }' > "$STATE_FILE"
chmod 0644 "$STATE_FILE"
