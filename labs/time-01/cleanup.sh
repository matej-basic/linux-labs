#!/bin/bash
# time-01 cleanup: puts nodes 1 and 2 back into the state that the first
# setup.sh run recorded in /var/tmp/time-01.pre on each node: the chrony
# configuration files, the boot and running state of chronyd, the ntp
# firewall service and the time zone. Where the lab installed chrony,
# chronyd stops and its data goes, so that the account chrony owns no
# file; then the package set of the first start comes back
# (lib/packages.sh). When a node cannot be restored, its records stay
# for the next reset and the exit status is 1.
# No "set -u": load-config.sh reads variables that may be unset.

source /opt/linux-labs/lib/load-config.sh
source /opt/linux-labs/lib/packages.sh
load_lab_config

LAB=time-01
STATE_FILE="/opt/linux-labs/state/$LAB"

# Nothing was started without multi-node support
if [ "$NODES_ENABLED" != "true" ] || ! [ "$NODE_COUNT" -ge 2 ] 2>/dev/null; then
	rm -f "$STATE_FILE"
	exit 0
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Before the package restore: configuration, service, firewall and time
# zone as recorded
cat > "$tmp/node.sh" <<'REMOTE'
pre=/var/tmp/time-01.pre
paths="/etc/chrony.conf /etc/chrony.keys /etc/sysconfig/chronyd /etc/chrony.d"
snap=/opt/linux-labs/state/time-01.packages/packages

# setup.sh never recorded this node: nothing to undo
[ -d "$pre" ] || exit 0

had() {
	grep -qx "$1" "$pre/flags" 2>/dev/null
}

for p in $paths; do
	saved="$pre/files/${p##*/}"
	if [ -e "$saved" ]; then
		if [ -f "$saved" ] && [ -f "$p" ] && cmp -s "$saved" "$p"; then
			continue
		fi
		rm -rf "$p"
		cp -a "$saved" "$p" || exit 1
	else
		rm -rf "$p"
	fi
done

if systemctl is-active --quiet firewalld; then
	if had fw-ntp; then
		firewall-cmd --permanent --add-service=ntp </dev/null >/dev/null 2>&1
	else
		firewall-cmd --permanent --remove-service=ntp </dev/null >/dev/null 2>&1
	fi
	firewall-cmd --reload </dev/null >/dev/null 2>&1
fi

tz=$(cat "$pre/timezone" 2>/dev/null)
if [ -n "$tz" ] && [ "$(timedatectl show -p Timezone --value </dev/null 2>/dev/null)" != "$tz" ]; then
	timedatectl set-timezone "$tz" </dev/null >/dev/null 2>&1 || {
		echo "cannot set the time zone $tz" >&2
		exit 1
	}
fi

if [ -s "$snap" ] && ! grep -q '^chrony\.' "$snap"; then
	# The lab installed chrony: its data goes before the package
	systemctl disable --now chronyd </dev/null >/dev/null 2>&1
	rm -rf /var/lib/chrony /var/log/chrony /run/chrony
else
	if had chronyd-enabled; then
		systemctl enable chronyd </dev/null >/dev/null 2>&1
	else
		systemctl disable chronyd </dev/null >/dev/null 2>&1
	fi
	if had chronyd-active; then
		systemctl restart chronyd </dev/null >/dev/null 2>&1 || {
			echo "chronyd does not start" >&2
			exit 1
		}
	else
		systemctl stop chronyd </dev/null >/dev/null 2>&1
	fi
fi
exit 0
REMOTE

rc=0
for n in 2 1; do
	ip=$(get_node_ip "$n")
	if ! run_on_node "$ip" "sudo -n bash -s" < "$tmp/node.sh" > "$tmp/out" 2>&1; then
		echo "Cleanup of node $n ($ip) failed:" >&2
		grep -v "^Warning: Permanently added" "$tmp/out" >&2
		rc=1
		continue
	fi
	pkg_restore_node "$ip" "$LAB" 2>"$tmp/err" || {
		echo "Restoring the packages of node $n ($ip) failed:" >&2
		grep -v "^Warning: Permanently added" "$tmp/err" >&2
		# Keep the records of this node for the next reset
		rc=1
		continue
	}
	if ! run_on_node "$ip" "sudo -n rm -rf /var/tmp/time-01.pre" </dev/null > "$tmp/out" 2>&1; then
		echo "Cleanup of node $n ($ip) failed:" >&2
		grep -v "^Warning: Permanently added" "$tmp/out" >&2
		rc=1
	fi
done

[ "$rc" -eq 0 ] && rm -f "$STATE_FILE"
exit "$rc"
