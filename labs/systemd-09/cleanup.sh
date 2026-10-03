#!/bin/bash
# systemd-09 cleanup: stop and remove the lab units and programs, end
# leftover processes, remove culprit.txt and the sysstat drop-in, then
# restore the package set of the first start (pkg_restore). When sysstat
# was installed before the lab, put back its configuration, drop-ins,
# /var/log/sa and unit states as setup.sh recorded them. Safe when the
# lab was never started.
source /opt/linux-labs/lib/packages.sh

LAB=systemd-09
STATE_FILE=/opt/linux-labs/state/$LAB
BAK=/var/tmp/$LAB.bak
LIBEXEC=/usr/local/libexec
UNITDIR=/etc/systemd/system
SYSSTAT_UNITS="sysstat.service sysstat-collect.timer sysstat-summary.timer"
SYSSTAT_DIRS="var/log/sa etc/systemd/system/sysstat-collect.timer.d"
rc=0

state_value() {
	awk -v k="$1" '$1 == k { print $2; exit }' "$STATE_FILE" 2>/dev/null
}

owner=$(state_value owner)
owner=${owner:-${LAB_USER:-}}
pre=$(state_value sysstat_preinstalled)

# The lab units and programs
for u in report-cache.timer report-cache.service index-builder.service; do
	systemctl disable --now "$u" >/dev/null 2>&1 || true
done
lab_processes() {
	pgrep -x report-cache
	pgrep -x index-builder
	pgrep -f "^([^ ]*/)?(ba)?sh $LIBEXEC/report-cache"
	pgrep -f "^([^ ]*/)?g?awk -f $LIBEXEC/index-builder"
}
# The lab processes and their children (the sleep of index-builder)
for _ in $(seq 1 20); do
	pids=$(lab_processes | sort -u | paste -sd, -)
	[ -n "$pids" ] || break
	# shellcheck disable=SC2046 # one PID per word
	kill -KILL $(echo "$pids" | tr , ' ') $(pgrep -P "$pids") 2>/dev/null || true
	sleep 0.25
done
if [ -n "$(lab_processes)" ]; then
	echo "$LAB: some lab processes are still running" >&2
	rc=1
fi
rm -f "$UNITDIR/report-cache.service" "$UNITDIR/report-cache.timer" \
	"$UNITDIR/index-builder.service" \
	"$UNITDIR/timers.target.wants/report-cache.timer" \
	"$UNITDIR/multi-user.target.wants/index-builder.service" \
	"$LIBEXEC/report-cache" "$LIBEXEC/index-builder"
rm -rf "$UNITDIR/report-cache.service.d" "$UNITDIR/report-cache.timer.d" \
	"$UNITDIR/index-builder.service.d"

if [ -n "$owner" ]; then
	home=$(getent passwd "$owner" | cut -d: -f6)
	[ -n "$home" ] && rm -f "$home/culprit.txt"
fi

# sysstat: the drop-in or a full copy of the timer from the solution
for u in $SYSSTAT_UNITS; do
	systemctl disable --now "$u" >/dev/null 2>&1 || true
done
rm -rf "$UNITDIR/sysstat-collect.timer" "$UNITDIR/sysstat-collect.timer.d"
# The data of a sysstat the lab installed goes before pkg_restore
if ! pkg_was_installed "$LAB" sysstat; then
	rm -rf /var/log/sa
	rm -f /etc/sysconfig/sysstat.rpmsave /etc/sysconfig/sysstat.ioconf.rpmsave
fi
systemctl daemon-reload >/dev/null 2>&1 || true
for u in report-cache.timer report-cache.service index-builder.service \
	$SYSSTAT_UNITS sysstat-collect.service sysstat-summary.service; do
	systemctl reset-failed "$u" >/dev/null 2>&1 || true
done

pkg_restore "$LAB" || rc=1

if [ "$pre" = yes ] && [ "$rc" -eq 0 ]; then
	if [ -f "$BAK/files.tar" ]; then
		# Delete files the lab added, then restore the recorded ones
		tar -tf "$BAK/files.tar" | sed 's|/$||' | sort > "$BAK/list"
		for p in $SYSSTAT_DIRS; do
			[ -d "/$p" ] || continue
			find "/$p" \( -type f -o -type l \) 2>/dev/null
		done | while read -r f; do
			f=${f#/}
			grep -qxF "$f" "$BAK/list" || rm -f "/$f"
		done
		tar --selinux --xattrs --acls -C / -xpf "$BAK/files.tar" || rc=1
	fi
	rm -f /etc/sysconfig/sysstat.rpmsave /etc/sysconfig/sysstat.ioconf.rpmsave
	systemctl daemon-reload >/dev/null 2>&1 || true
	# The package scriptlet presets the units, and enabling
	# sysstat.service enables both timers through Also=. Set the
	# recorded enable states first (in the recorded order, sysstat.service
	# first), then start or stop each unit.
	units=$(awk '$1 == "unit"' "$STATE_FILE")
	while read -r _ u en _; do
		[ -n "$u" ] || continue
		if [ "$en" = yes ]; then
			systemctl enable "$u" >/dev/null 2>&1 || rc=1
		else
			systemctl disable "$u" >/dev/null 2>&1 || rc=1
		fi
	done <<<"$units"
	while read -r _ u _ act; do
		[ -n "$u" ] || continue
		if [ "$act" = yes ]; then
			systemctl start "$u" >/dev/null 2>&1 || rc=1
		else
			systemctl stop "$u" >/dev/null 2>&1 || true
		fi
	done <<<"$units"
fi

systemctl daemon-reload >/dev/null 2>&1 || true
if [ "$rc" -eq 0 ]; then
	rm -rf "$BAK"
	rm -f "$STATE_FILE"
fi
exit "$rc"
