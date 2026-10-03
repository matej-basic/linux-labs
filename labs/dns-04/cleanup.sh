#!/bin/bash
# dns-04 cleanup: puts nodes 1 and 2 back into the state that the first
# setup.sh run recorded in /var/tmp/dns-04.pre on each node. named is
# stopped and disabled. Where bind was not installed at the first
# start, /var/named, /etc/named.conf (with any copies of it) and
# /etc/rndc.key go before the package restore, so that pkg_restore can
# remove the named user and group the package created. Where bind was
# installed, /etc/named.conf comes back from the recorded copy, the
# files under /var/named that are new since the first start go, and
# named gets its recorded unit state back after the package restore.
# The firewall ports and services added or removed since the first
# start are put back (runtime and permanent), then the package set of
# the first start comes back on each node (lib/packages.sh).
# A node without records was never prepared and is left alone. When a
# node cannot be restored, its records stay for the next reset and the
# exit status is 1.
# No "set -u": load-config.sh reads variables that may be unset.

source /opt/linux-labs/lib/load-config.sh
source /opt/linux-labs/lib/packages.sh
load_lab_config

LAB=dns-04
STATE_FILE="/opt/linux-labs/state/$LAB"

# Nothing was started without multi-node support
if [ "$NODES_ENABLED" != "true" ] || ! [ "$NODE_COUNT" -ge 2 ] 2>/dev/null; then
	rm -f "$STATE_FILE"
	exit 0
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Both nodes, before the package restore
cat > "$tmp/pre.sh" <<'REMOTE'
pre=/var/tmp/dns-04.pre
rc=0

[ -d "$pre" ] || exit 0

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
	LC_ALL=C comm -13 "$rec" "$pre/fw.now" | while read -r zone kind val; do
		firewall-cmd "$@" --zone="$zone" --remove-"$kind"="$val" >/dev/null
	done
	LC_ALL=C comm -23 "$rec" "$pre/fw.now" | while read -r zone kind val; do
		firewall-cmd "$@" --zone="$zone" --add-"$kind"="$val" >/dev/null
	done
	fw_dump "$@" > "$pre/fw.now" || return 1
	cmp -s "$rec" "$pre/fw.now"
}

systemctl disable --now named </dev/null >/dev/null 2>&1
systemctl reset-failed named </dev/null >/dev/null 2>&1

if had bind-installed; then
	if [ -f "$pre/named.conf" ]; then
		cp -a "$pre/named.conf" /etc/named.conf || rc=1
	else
		rm -f /etc/named.conf
	fi
	if [ -d /var/named ]; then
		find /var/named -xdev ! -type d | LC_ALL=C sort > "$pre/files.now"
		LC_ALL=C comm -13 "$pre/files" "$pre/files.now" | while IFS= read -r f; do
			rm -f "$f"
		done
		rm -f "$pre/files.now"
	fi
else
	had var-named-existed || rm -rf /var/named
	rm -f /etc/named.conf /etc/named.conf.* /etc/rndc.key
fi

if firewall-cmd --state >/dev/null 2>&1; then
	fw_restore "$pre/fw.runtime" || { echo "firewall runtime rules not restored" >&2; rc=1; }
	fw_restore "$pre/fw.permanent" --permanent || { echo "firewall permanent rules not restored" >&2; rc=1; }
	rm -f "$pre/fw.now"
else
	echo "firewalld is not running, the firewall was not restored" >&2
	rc=1
fi
exit "$rc"
REMOTE

# Both nodes, after the package restore: named as recorded where bind
# was there before the lab
cat > "$tmp/post.sh" <<'REMOTE'
pre=/var/tmp/dns-04.pre

[ -d "$pre" ] || exit 0

had() {
	grep -qx "$1" "$pre/flags" 2>/dev/null
}

if had bind-installed && systemctl cat named </dev/null >/dev/null 2>&1; then
	if had named-enabled; then
		systemctl enable named </dev/null >/dev/null 2>&1
	fi
	if had named-active; then
		systemctl start named </dev/null >/dev/null 2>&1 || exit 1
	fi
fi
rm -rf "$pre"
exit 0
REMOTE

rc=0
for n in 2 1; do
	ip=$(get_node_ip "$n")
	if ! run_on_node "$ip" "sudo -n bash -s" < "$tmp/pre.sh" > /dev/null 2> "$tmp/err"; then
		echo "Cleanup of node $n ($ip) failed:" >&2
		grep -v "^Warning: Permanently added" "$tmp/err" >&2
		rc=1
		continue
	fi
	if ! pkg_restore_node "$ip" "$LAB" 2> "$tmp/err"; then
		echo "Restoring the packages of node $n ($ip) failed:" >&2
		grep -v "^Warning: Permanently added" "$tmp/err" >&2
		# Keep the records of this node for the next reset
		rc=1
		continue
	fi
	if ! run_on_node "$ip" "sudo -n bash -s" < "$tmp/post.sh" > /dev/null 2> "$tmp/err"; then
		echo "Cleanup of node $n ($ip) failed:" >&2
		grep -v "^Warning: Permanently added" "$tmp/err" >&2
		rc=1
	fi
done

[ "$rc" -eq 0 ] && rm -f "$STATE_FILE"
exit "$rc"
