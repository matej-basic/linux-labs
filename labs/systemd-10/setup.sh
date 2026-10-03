#!/bin/bash
# systemd-10 setup: three custom services in /etc/systemd/system, each
# with a program in /usr/local/bin and its own system user, and each
# failing to start for a different reason:
#   - reportd: the program was written in /root and moved, so it keeps
#     the type admin_home_t, and it has no execute bit (203/EXEC)
#   - inventoryd: EnvironmentFile=/etc/sysconfig/inventoryd does not
#     exist; the prepared settings are in inventoryd.example, and the
#     program exits 1 without them
#   - metricsd: Type=forking for a program that stays in the
#     foreground, so the start times out after 20 seconds, and the unit
#     has no [Install] section
# reportd is enabled, inventoryd and metricsd are disabled. Every
# service is started once without waiting, so the failures are in the
# journal. Prints nothing on success.
#
# The first run records the package set (pkg_snapshot, in case the
# student installs semanage), the SELinux mode, the booleans, the policy
# modules at priority 400 and the local file context rules. Every run
# writes the checksums of the programs to the state file for the grader.
set -eu
source /opt/linux-labs/lib/packages.sh

LAB=systemd-10
STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/$LAB"
REC_DIR="$STATE_DIR/$LAB.d"
UNITDIR=/etc/systemd/system
BIN=/usr/local/bin
SVCS="reportd inventoryd metricsd"
GECOS="linux-labs systemd-10"

fail() {
	echo "Error: $*" >&2
	exit 1
}

if ! command -v getenforce >/dev/null 2>&1 || [ "$(getenforce)" = Disabled ]; then
	fail "SELinux is disabled; this lab needs SELinux enabled."
fi
for cmd in restorecon semodule getsebool systemd-analyze useradd; do
	command -v "$cmd" >/dev/null 2>&1 || fail "the command $cmd is missing."
done

# The users must not exist unless this lab created them
for s in $SVCS; do
	if getent passwd "$s" >/dev/null &&
		[ "$(getent passwd "$s" | cut -d: -f5)" != "$GECOS" ]; then
		fail "the user $s already exists and does not belong to this lab."
	fi
done

pkg_snapshot "$LAB" || fail "cannot record the package set."

fc_local() {
	local type
	type=$(sed -n 's/^SELINUXTYPE=//p' /etc/selinux/config | head -n 1)
	echo "/etc/selinux/${type:-targeted}/contexts/files/file_contexts.local"
}

state_value() {
	sed -n "s/^$1=//p" "$STATE_FILE" 2>/dev/null | head -n 1
}

# First run only: the SELinux settings before the lab
if [ ! -r "$STATE_FILE" ]; then
	rm -rf "$REC_DIR"
	mkdir -p "$STATE_DIR"
	mkdir -m 0755 "$REC_DIR"
	fc=$(fc_local)
	if [ -r "$fc" ]; then
		grep -v '^#' "$fc" | awk 'NF' > "$REC_DIR/file_contexts.local"
	else
		: > "$REC_DIR/file_contexts.local"
	fi
	getsebool -a > "$REC_DIR/booleans"
	chmod 0644 "$REC_DIR/file_contexts.local" "$REC_DIR/booleans"
	tmp="$STATE_FILE.tmp"
	{
		echo "selinux_cfg=$(sed -n 's/^SELINUX=//p' /etc/selinux/config | head -n 1)"
		echo "selinux_mode=$(getenforce)"
		echo "modules=$(semodule -lfull 2>/dev/null |
			awk '$1 == 400 { print $2 }' | sort | tr '\n' ' ')"
	} > "$tmp"
	chmod 0644 "$tmp"
	mv "$tmp" "$STATE_FILE"
fi

# Put the local SELinux customizations back to the recorded state: file
# context rules added since the first start (semanage, if the student
# installed it), booleans, and policy modules added at priority 400
# (audit2allow modules)
selinux_restore() {
	local rec="$REC_DIR/file_contexts.local" fc added line p m val before
	if [ -r "$rec" ] && command -v semanage >/dev/null 2>&1; then
		fc=$(fc_local)
		added=$({ [ -r "$fc" ] && cat "$fc"; } | grep -v '^#' | awk 'NF' |
			grep -vxF -f "$rec" | awk '{ print $1 }' || true)
		if [ -n "$added" ]; then
			semanage export 2>/dev/null | grep '^fcontext -a ' |
				while IFS= read -r line; do
					p=$(printf '%s\n' "$line" | awk '{ print $NF }' | tr -d "'")
					printf '%s\n' "$added" | grep -qxF -- "$p" || continue
					printf '%s\n' "${line/fcontext -a /fcontext -d }" |
						semanage import >/dev/null 2>&1 || true
				done
		fi
	fi
	if [ -r "$REC_DIR/booleans" ]; then
		getsebool -a 2>/dev/null | grep -vxF -f "$REC_DIR/booleans" |
			awk '{ print $1 }' | while read -r m; do
				val=$(awk -v b="$m" '$1 == b { print $3 }' "$REC_DIR/booleans")
				[ -n "$val" ] && setsebool -P "$m" "$val" >/dev/null 2>&1
				true
			done
	fi
	before=$(state_value modules)
	for m in $(semodule -lfull 2>/dev/null | awk '$1 == 400 { print $2 }'); do
		case " $before " in
		*" $m "*) ;;
		*) semodule -X 400 -r "$m" >/dev/null 2>&1 || true ;;
		esac
	done
}

# Remove what an earlier run or the solution left behind
for s in $SVCS; do
	systemctl disable --now "$s.service" >/dev/null 2>&1 || true
	systemctl kill -s KILL "$s.service" >/dev/null 2>&1 || true
done
for s in $SVCS; do
	pkill -KILL -u "$s" 2>/dev/null || true
	rm -rf "${UNITDIR:?}/$s.service" "${UNITDIR:?}/$s.service.d" \
		"/run/systemd/system/$s.service" "/run/systemd/system/$s.service.d"
	find "$UNITDIR" -maxdepth 2 -type l -name "$s.service" -delete 2>/dev/null || true
	rm -f "${BIN:?}/$s" "/root/$s"
done
rm -f /etc/sysconfig/inventoryd /etc/sysconfig/inventoryd.example
rm -rf /var/lib/inventoryd
selinux_restore
setenforce 1
sed -i 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config

# The users
for s in $SVCS; do
	if ! getent passwd "$s" >/dev/null; then
		useradd -r -M -d / -s /sbin/nologin -c "$GECOS" "$s"
	fi
done

# The programs
mkdir -p "$BIN"
# reportd: written in /root and moved, without the execute bit
cat > /root/reportd <<'PROGRAM'
#!/bin/bash
# reportd: checks the system once a minute for the status report
while :; do
	uptime >/dev/null
	sleep 60
done
PROGRAM
chown root:root /root/reportd
chmod 0644 /root/reportd
mv /root/reportd "$BIN/reportd"

cat > "$BIN/inventoryd" <<'PROGRAM'
#!/bin/bash
# inventoryd: scans the inventory directory at a fixed interval.
# It needs INVENTORY_DIR and SCAN_INTERVAL in its environment.
if [ -z "${INVENTORY_DIR:-}" ] || [ -z "${SCAN_INTERVAL:-}" ]; then
	echo "inventoryd: INVENTORY_DIR and SCAN_INTERVAL must be set" >&2
	exit 1
fi
case $SCAN_INTERVAL in
'' | *[!0-9]*)
	echo "inventoryd: SCAN_INTERVAL must be a number of seconds" >&2
	exit 1
	;;
esac
if [ ! -d "$INVENTORY_DIR" ]; then
	echo "inventoryd: $INVENTORY_DIR is not a directory" >&2
	exit 1
fi
while :; do
	ls "$INVENTORY_DIR" >/dev/null
	sleep "$SCAN_INTERVAL"
done
PROGRAM

cat > "$BIN/metricsd" <<'PROGRAM'
#!/bin/bash
# metricsd: reads the load average every 10 seconds
while :; do
	read -r load _ </proc/loadavg
	: "$load"
	sleep 10
done
PROGRAM
chmod 0755 "$BIN/inventoryd" "$BIN/metricsd"
restorecon "$BIN/inventoryd" "$BIN/metricsd"

# The settings of inventoryd, prepared but never put in place
mkdir -m 0750 /var/lib/inventoryd
chown inventoryd:inventoryd /var/lib/inventoryd
cat > /etc/sysconfig/inventoryd.example <<'CONF'
# inventoryd settings
INVENTORY_DIR=/var/lib/inventoryd
SCAN_INTERVAL=30
CONF
chmod 0644 /etc/sysconfig/inventoryd.example
restorecon -R /var/lib/inventoryd /etc/sysconfig/inventoryd.example

# The units
cat > "$UNITDIR/reportd.service" <<'UNIT'
[Unit]
Description=Status report daemon
After=network.target

[Service]
Type=simple
User=reportd
ExecStart=/usr/local/bin/reportd

[Install]
WantedBy=multi-user.target
UNIT
cat > "$UNITDIR/inventoryd.service" <<'UNIT'
[Unit]
Description=Inventory scanner
After=network.target

[Service]
Type=simple
User=inventoryd
EnvironmentFile=/etc/sysconfig/inventoryd
ExecStart=/usr/local/bin/inventoryd

[Install]
WantedBy=multi-user.target
UNIT
cat > "$UNITDIR/metricsd.service" <<'UNIT'
[Unit]
Description=Load metrics collector
After=network.target

[Service]
Type=forking
User=metricsd
ExecStart=/usr/local/bin/metricsd
TimeoutStartSec=20s
UNIT
for s in $SVCS; do
	chmod 0644 "$UNITDIR/$s.service"
	restorecon "$UNITDIR/$s.service"
done

systemctl daemon-reload
for s in $SVCS; do
	systemctl reset-failed "$s.service" >/dev/null 2>&1 || true
done
systemctl enable reportd.service >/dev/null 2>&1 || fail "cannot enable reportd.service."

# The checksums the grader compares
tmp="$STATE_FILE.tmp"
{
	grep -v '^sum_' "$STATE_FILE"
	for s in $SVCS; do
		echo "sum_$s=$(sha256sum "$BIN/$s" | awk '{ print $1 }')"
	done
} > "$tmp"
chmod 0644 "$tmp"
mv "$tmp" "$STATE_FILE"

# Each service was tried once; metricsd times out in the background
for s in $SVCS; do
	systemctl start --no-block "$s.service" >/dev/null 2>&1 || true
done
exit 0
