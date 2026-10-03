#!/bin/bash
# logging-05 cleanup: on both nodes, with the records setup.sh kept in
# /var/tmp/logging-05.pre: puts /etc/rsyslog.conf and /etc/rsyslog.d back
# as they were (drop-in files the lab or the solution added go), undoes
# the firewall ports and services added since the first start (runtime
# and permanent) and adds back removed ones, stops rsyslog, removes the
# new files in /var/lib/rsyslog (queue spool files) and /var/log/remote,
# and starts rsyslog again in its recorded unit state. Then the package
# set of the first start comes back on both nodes.
# A node without records was never prepared and is left alone.
# No "set -u": load-config.sh reads variables that may be unset.

source /opt/linux-labs/lib/load-config.sh
source /opt/linux-labs/lib/packages.sh
load_lab_config

LAB=logging-05
rm -f "/opt/linux-labs/state/$LAB"

# Nothing was started without multi-node support
[ "$NODES_ENABLED" = "true" ] || exit 0
[ "$NODE_COUNT" -ge 2 ] 2>/dev/null || exit 0

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

cat > "$tmp/node.sh" <<'REMOTE'
pre=/var/tmp/logging-05.pre
[ -d "$pre" ] || exit 0
rc=0

had() {
	grep -qx "$1" "$pre/flags" 2>/dev/null
}

fw_dump() {
	firewall-cmd "$@" --list-all-zones | awk '
		/^[^ \t]/ { zone = $1 }
		/^[ \t]+services:/ { for (i = 2; i <= NF; i++) print zone, "service", $i }
		/^[ \t]+ports:/ { for (i = 2; i <= NF; i++) print zone, "port", $i }
	' | LC_ALL=C sort
}

# fw_restore <recorded file> [--permanent]
fw_restore() {
	local rec=$1 zone kind val
	shift
	[ -f "$rec" ] || return 0
	fw_dump "$@" > "$pre/fw.now" || return 1
	# Added since the first start
	LC_ALL=C comm -13 "$rec" "$pre/fw.now" | while read -r zone kind val; do
		firewall-cmd "$@" --zone="$zone" --remove-"$kind"="$val" >/dev/null
	done
	# Removed since the first start
	LC_ALL=C comm -23 "$rec" "$pre/fw.now" | while read -r zone kind val; do
		firewall-cmd "$@" --zone="$zone" --add-"$kind"="$val" >/dev/null
	done
	fw_dump "$@" > "$pre/fw.now" || return 1
	cmp -s "$rec" "$pre/fw.now"
}

# Configuration files
if [ -f "$pre/rsyslog.conf" ] && ! cmp -s "$pre/rsyslog.conf" /etc/rsyslog.conf; then
	cp -a "$pre/rsyslog.conf" /etc/rsyslog.conf || rc=1
fi
if [ -d "$pre/rsyslog.d" ]; then
	rm -rf /etc/rsyslog.d
	cp -a "$pre/rsyslog.d" /etc/rsyslog.d || rc=1
fi
restorecon -R /etc/rsyslog.conf /etc/rsyslog.d >/dev/null 2>&1

# Firewall
if firewall-cmd --state >/dev/null 2>&1; then
	fw_restore "$pre/fw.runtime" || { echo "firewall runtime rules not restored" >&2; rc=1; }
	fw_restore "$pre/fw.permanent" --permanent || { echo "firewall permanent rules not restored" >&2; rc=1; }
	rm -f "$pre/fw.now"
else
	echo "firewalld is not running, the firewall was not restored" >&2
	rc=1
fi

# rsyslog: stopped while its queue files and the remote logs go
systemctl stop rsyslog >/dev/null 2>&1
if [ -f "$pre/workdir" ] && [ -d /var/lib/rsyslog ]; then
	ls -A /var/lib/rsyslog | while read -r f; do
		grep -qxF -- "$f" "$pre/workdir" || rm -rf "/var/lib/rsyslog/$f"
	done
fi
had remote-existed || rm -rf /var/log/remote
if had rsyslog-enabled; then
	systemctl enable rsyslog >/dev/null 2>&1 || rc=1
else
	systemctl disable rsyslog >/dev/null 2>&1
fi
if had rsyslog-active; then
	systemctl start rsyslog || rc=1
fi

[ "$rc" -eq 0 ] && rm -rf "$pre"
exit "$rc"
REMOTE

rc=0
for n in 1 2; do
	ip=$(get_node_ip "$n")
	if ! run_on_node "$ip" "sudo -n bash -s" < "$tmp/node.sh" > /dev/null 2> "$tmp/err"; then
		echo "Cleanup of node $n ($ip) failed:" >&2
		grep -v "^Warning: Permanently added" "$tmp/err" >&2
		rc=1
		continue
	fi
	if ! pkg_restore_node "$ip" "$LAB" 2> "$tmp/err"; then
		echo "Restoring the packages of node $n ($ip) failed:" >&2
		grep -v "^Warning: Permanently added" "$tmp/err" >&2
		rc=1
	fi
done
exit "$rc"
