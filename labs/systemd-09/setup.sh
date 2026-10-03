#!/bin/bash
# systemd-09 setup: start two resource hogs and remove sysstat. Prints
# nothing on success.
#
# The CPU hog report-cache is a busy loop in report-cache.service, which
# report-cache.timer starts again every minute, so killing the process
# alone does not help. CPUQuota and nice 19 keep the machine usable. The
# memory hog index-builder holds about 250 MiB in index-builder.service,
# with Restart=always and MemoryMax as a safety cap.
#
# The first run records the package set (pkg_snapshot), whether sysstat
# was installed and the state of its units, and, when it was installed,
# a copy of its configuration, its drop-ins and /var/log/sa in
# /var/tmp/systemd-09.bak. cleanup.sh puts all of it back.
set -eu
source /opt/linux-labs/lib/packages.sh

LAB=systemd-09
STATE_DIR=/opt/linux-labs/state
STATE_FILE=$STATE_DIR/$LAB
BAK=/var/tmp/$LAB.bak
LIBEXEC=/usr/local/libexec
UNITDIR=/etc/systemd/system
SYSSTAT_UNITS="sysstat.service sysstat-collect.timer sysstat-summary.timer"
SYSSTAT_PATHS="etc/sysconfig/sysstat etc/sysconfig/sysstat.ioconf var/log/sa
etc/systemd/system/sysstat-collect.timer
etc/systemd/system/sysstat-collect.timer.d"

fail() {
	echo "$LAB: $*" >&2
	exit 1
}

for cmd in gawk bash pgrep systemctl; do
	command -v "$cmd" >/dev/null 2>&1 || fail "the command $cmd is missing"
done

# Task user, as in files-04
owner="${LAB_USER:-student}"
if ! id "$owner" &>/dev/null; then
	owner=$(getent passwd | awk -F: '$3 >= 1000 && $3 < 60000 { print $1; exit }')
	[ -n "$owner" ] || fail "no regular user for the task"
fi
home=$(getent passwd "$owner" | cut -d: -f6)

pkg_snapshot "$LAB" || fail "cannot record the package set"

# First start: record sysstat as it was before the lab
if [ ! -r "$STATE_FILE" ]; then
	rm -rf "$BAK"
	mkdir -m 0700 "$BAK"
	pre=no
	unit_states=""
	if rpm -q sysstat >/dev/null 2>&1; then
		pre=yes
		for u in $SYSSTAT_UNITS; do
			en=no
			act=no
			systemctl is-enabled --quiet "$u" 2>/dev/null && en=yes
			systemctl is-active --quiet "$u" 2>/dev/null && act=yes
			unit_states="${unit_states}unit $u $en $act
"
		done
		keep=""
		for p in $SYSSTAT_PATHS; do
			[ -e "/$p" ] && keep="$keep $p"
		done
		if [ -n "$keep" ]; then
			# shellcheck disable=SC2086 # one path per word
			tar --selinux --xattrs --acls -C / -cpf "$BAK/files.tar" $keep
		fi
	fi
	mkdir -p "$STATE_DIR"
	{
		echo "owner $owner"
		echo "sysstat_preinstalled $pre"
		printf '%s' "$unit_states"
	} > "$STATE_FILE"
	chmod 644 "$STATE_FILE"
fi

# Remove what an earlier run or the solution left behind
for u in report-cache.timer report-cache.service index-builder.service; do
	systemctl disable --now "$u" >/dev/null 2>&1 || true
done
pkill -KILL -f "^([^ ]*/)?(ba)?sh $LIBEXEC/report-cache" 2>/dev/null || true
pkill -KILL -x report-cache 2>/dev/null || true
pkill -KILL -x index-builder 2>/dev/null || true
rm -f "$home/culprit.txt"

# No sysstat, as the task starts. Removing the package also deletes
# /var/log/sa/* (recorded above when it was there before the lab).
for u in $SYSSTAT_UNITS; do
	systemctl disable --now "$u" >/dev/null 2>&1 || true
done
if rpm -q sysstat >/dev/null 2>&1; then
	dnf -y remove sysstat </dev/null >/dev/null 2>&1 ||
		fail "could not remove the sysstat package"
fi
rm -rf "$UNITDIR/sysstat-collect.timer" "$UNITDIR/sysstat-collect.timer.d" \
	/var/log/sa /etc/sysconfig/sysstat.rpmsave

# The programs
mkdir -p "$LIBEXEC"
cat > "$LIBEXEC/report-cache" <<'PROGRAM'
#!/bin/bash
# report-cache: refreshes the report cache
while :; do
	:
done
PROGRAM
cat > "$LIBEXEC/index-builder" <<'PROGRAM'
#!/usr/bin/gawk -f
# index-builder: keeps the search index in memory
BEGIN {
	index_buf = sprintf("%*s", 240 * 1024 * 1024, "")
	while (1)
		system("exec sleep 3600")
}
PROGRAM
chmod 0755 "$LIBEXEC/report-cache" "$LIBEXEC/index-builder"

# The units
cat > "$UNITDIR/report-cache.service" <<'UNIT'
[Unit]
Description=Report cache refresh

[Service]
Type=simple
ExecStart=/usr/local/libexec/report-cache
Nice=19
CPUQuota=50%
UNIT
cat > "$UNITDIR/report-cache.timer" <<'UNIT'
[Unit]
Description=Refresh the report cache every minute

[Timer]
OnCalendar=*-*-* *:*:00
AccuracySec=1s

[Install]
WantedBy=timers.target
UNIT
cat > "$UNITDIR/index-builder.service" <<'UNIT'
[Unit]
Description=Search index builder

[Service]
Type=simple
ExecStart=/usr/local/libexec/index-builder
Restart=always
RestartSec=3
MemoryMax=320M

[Install]
WantedBy=multi-user.target
UNIT
chmod 0644 "$UNITDIR/report-cache.service" "$UNITDIR/report-cache.timer" \
	"$UNITDIR/index-builder.service"
restorecon "$LIBEXEC/report-cache" "$LIBEXEC/index-builder" \
	"$UNITDIR/report-cache.service" "$UNITDIR/report-cache.timer" \
	"$UNITDIR/index-builder.service" >/dev/null 2>&1 || true

systemctl daemon-reload
for u in report-cache.timer report-cache.service index-builder.service; do
	systemctl reset-failed "$u" >/dev/null 2>&1 || true
done
systemctl enable --now report-cache.timer >/dev/null 2>&1 ||
	fail "cannot start report-cache.timer"
systemctl start report-cache.service || fail "cannot start report-cache.service"
systemctl enable --now index-builder.service >/dev/null 2>&1 ||
	fail "cannot start index-builder.service"

# Wait until both programs run under their own process names
for _ in $(seq 1 50); do
	if pgrep -x report-cache >/dev/null && pgrep -x index-builder >/dev/null; then
		exit 0
	fi
	sleep 0.2
done
fail "the lab processes did not start"
