#!/bin/bash
# systemd-10 cleanup: stop, disable and remove the three lab services,
# their drop-ins, programs and settings, end their processes and remove
# their users. Put the local SELinux customizations (file context rules,
# booleans, policy modules at priority 400) and the SELinux mode back as
# setup.sh recorded them at the first start, then restore the package
# set (pkg_restore). Safe when the lab was never started. When the
# package set cannot be restored, the records stay for the next reset
# and the exit status is 1.
source /opt/linux-labs/lib/packages.sh

LAB=systemd-10
STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/$LAB"
REC_DIR="$STATE_DIR/$LAB.d"
UNITDIR=/etc/systemd/system
BIN=/usr/local/bin
SVCS="reportd inventoryd metricsd"
GECOS="linux-labs systemd-10"
rc=0

state_value() {
	[ -r "$STATE_FILE" ] || return 0
	sed -n "s/^$1=//p" "$STATE_FILE" | head -n 1
}

fc_local() {
	local type
	type=$(sed -n 's/^SELINUXTYPE=//p' /etc/selinux/config | head -n 1)
	echo "/etc/selinux/${type:-targeted}/contexts/files/file_contexts.local"
}

# The same as in setup.sh
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

# The services, their files and their processes
for s in $SVCS; do
	systemctl disable --now "$s.service" >/dev/null 2>&1 || true
	systemctl kill -s KILL "$s.service" >/dev/null 2>&1 || true
done
for s in $SVCS; do
	rm -rf "${UNITDIR:?}/$s.service" "${UNITDIR:?}/$s.service.d" \
		"/run/systemd/system/$s.service" "/run/systemd/system/$s.service.d"
	find "$UNITDIR" -maxdepth 2 -type l -name "$s.service" -delete 2>/dev/null || true
	rm -f "${BIN:?}/$s" "/root/$s"
done
rm -f /etc/sysconfig/inventoryd /etc/sysconfig/inventoryd.example \
	/etc/sysconfig/inventoryd.rpmsave
rm -rf /var/lib/inventoryd
systemctl daemon-reload >/dev/null 2>&1 || true
for s in $SVCS; do
	systemctl reset-failed "$s.service" >/dev/null 2>&1 || true
done

# The users this lab created
for s in $SVCS; do
	getent passwd "$s" >/dev/null || continue
	[ "$(getent passwd "$s" | cut -d: -f5)" = "$GECOS" ] || continue
	for _ in $(seq 1 20); do
		pgrep -u "$s" >/dev/null || break
		pkill -KILL -u "$s" 2>/dev/null || true
		sleep 0.25
	done
	if ! userdel "$s" >/dev/null 2>&1; then
		echo "$LAB: cannot remove the user $s" >&2
		rc=1
	fi
done

# SELinux, while semanage is still there if the student installed it
if [ -r "$STATE_FILE" ]; then
	selinux_restore
	cfg=$(state_value selinux_cfg)
	if [ -n "$cfg" ]; then
		sed -i "s/^SELINUX=.*/SELINUX=$cfg/" /etc/selinux/config
	fi
	case $(state_value selinux_mode) in
	Enforcing) setenforce 1 >/dev/null 2>&1 || true ;;
	Permissive) setenforce 0 >/dev/null 2>&1 || true ;;
	esac
fi

pkg_restore "$LAB" || rc=1

if [ "$rc" -eq 0 ]; then
	rm -rf "$REC_DIR"
	rm -f "$STATE_FILE" "$STATE_FILE.tmp"
fi
exit "$rc"
