#!/bin/bash
# clustering-01 cleanup: destroys the cluster and puts every node back
# into the state that the first setup.sh run recorded. The cluster
# directories go first where they did not exist before the lab, so that
# the hacluster account and the haclient group own no file; then the
# package set of the first start comes back (lib/packages.sh), which
# removes Pacemaker, pcs and httpd where they were missing, together
# with the accounts they created, and installs them again where
# setup.sh removed them. The cluster directories, the index page, the
# httpd configuration, the hacluster password, the boot and running
# state of the services and the high-availability firewall service go
# back to their recorded values. When a node cannot be restored, its
# records stay for the next reset and the exit status is 1.
# No "set -u": load-config.sh reads variables that may be unset.

source /opt/linux-labs/lib/load-config.sh
source /opt/linux-labs/lib/packages.sh
load_lab_config

LAB=clustering-01
STATE_FILE="/opt/linux-labs/state/$LAB"

# Nothing was started without multi-node support
if [ "$NODES_ENABLED" != "true" ] || ! [ "$NODE_COUNT" -ge 3 ] 2>/dev/null; then
	rm -f "$STATE_FILE"
	exit 0
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Before the package restore: destroy the cluster, stop the services and
# remove the lab files and the cluster directories that setup.sh did not
# record
cat > "$tmp/stop.sh" <<'REMOTE'
pre=/var/tmp/clustering-01.pre
bak=/var/tmp/clustering-01.bak
dirs="/etc/corosync /var/lib/pacemaker /var/lib/corosync /var/lib/pcsd /var/log/pacemaker /var/log/cluster /var/log/pcsd"

# setup.sh never ran on this node: nothing to undo
[ -f "$pre" ] || exit 0

if command -v pcs >/dev/null 2>&1; then
	pcs cluster destroy </dev/null >/dev/null 2>&1
fi
systemctl disable --now pacemaker corosync pcsd httpd </dev/null >/dev/null 2>&1
pkill -x httpd >/dev/null 2>&1
rm -f /var/www/html/index.html /etc/httpd/conf/httpd.conf.rpmsave /etc/corosync/corosync.conf.rpmsave
for d in $dirs; do
	[ -f "$bak/$(echo "${d#/}" | tr / _).tar" ] || rm -rf "$d"
done

# rpcbind, which the resource agents pull in through nfs-utils, creates
# the rpc account without -r, so useradd also creates a mail spool.
# Where the account is new since the package snapshot, the NFS helper
# services stop and the account's files go too.
accounts=/opt/linux-labs/state/clustering-01.packages/accounts
if [ -s "$accounts" ] && getent passwd rpc >/dev/null && ! grep -qx user:rpc "$accounts"; then
	systemctl stop rpc-statd-notify rpcbind.socket rpcbind </dev/null >/dev/null 2>&1
	rm -rf /var/lib/rpcbind /var/spool/mail/rpc
fi
exit 0
REMOTE

# After the package restore: directories, files, password, services,
# firewall
cat > "$tmp/node.sh" <<'REMOTE'
pre=/var/tmp/clustering-01.pre
bak=/var/tmp/clustering-01.bak
dirs="/etc/corosync /var/lib/pacemaker /var/lib/corosync /var/lib/pcsd /var/log/pacemaker /var/log/cluster /var/log/pcsd"

# setup.sh never ran on this node: nothing to undo
[ -f "$pre" ] || exit 0

had() {
	grep -qx "$1" "$pre"
}

# undir <dir>: unless an installed package owns the directory, put it
# back as setup.sh found it: removed, or the copy setup.sh saved
undir() {
	rpm -qf "$1" >/dev/null 2>&1 && return 0
	rm -rf "$1"
	if [ -d "$bak/dirs$1" ]; then
		mkdir -p "$(dirname "$1")" && cp -a "$bak/dirs$1" "$1" && restorecon -R "$1" 2>/dev/null
	fi
	return 0
}

rm -f /etc/httpd/conf/httpd.conf.rpmsave /etc/corosync/corosync.conf.rpmsave
if ! rpm -q httpd >/dev/null 2>&1; then
	undir /etc/httpd
	undir /var/log/httpd
	undir /var/www
fi

# Cluster directories: the recorded copy where there was one, else gone
# unless a package owns them
for d in $dirs; do
	t="$bak/$(echo "${d#/}" | tr / _).tar"
	if [ -f "$t" ]; then
		rm -rf "$d"
		tar --selinux --xattrs --acls -C / -xpf "$t" || exit 1
		restorecon -R "$d" 2>/dev/null
	elif [ -d "$d" ]; then
		rpm -qf "$d" >/dev/null 2>&1 || rm -rf "$d"
	fi
done

for f in /etc/httpd/conf/httpd.conf /var/www/html/index.html; do
	b="$bak/$(basename "$f")"
	if [ -f "$b" ] && [ -d "$(dirname "$f")" ]; then
		cp -a "$b" "$f" && restorecon "$f" 2>/dev/null
	fi
done

# The password of a hacluster account from before the lab
if had user-hacluster && [ -f "$bak/hacluster.shadow" ] && getent passwd hacluster >/dev/null; then
	usermod -p "$(cat "$bak/hacluster.shadow")" hacluster || exit 1
	lastchg=$(cat "$bak/hacluster.lastchg" 2>/dev/null)
	[ -n "$lastchg" ] && chage -d "$lastchg" hacluster
fi

for u in httpd pcsd pacemaker corosync; do
	systemctl cat "$u" </dev/null >/dev/null 2>&1 || continue
	had "$u-enabled" && systemctl enable "$u" </dev/null >/dev/null 2>&1
	had "$u-active" && systemctl start "$u" </dev/null >/dev/null 2>&1
done

if had fw-ha; then
	firewall-cmd --permanent --add-service=high-availability </dev/null >/dev/null 2>&1
else
	firewall-cmd --permanent --remove-service=high-availability </dev/null >/dev/null 2>&1
fi
firewall-cmd --reload </dev/null >/dev/null 2>&1

rm -rf "$pre" "$bak"
exit 0
REMOTE

rc=0
for n in 1 2 3; do
	ip=$(get_node_ip "$n")
	if ! run_on_node "$ip" "sudo -n bash -s" < "$tmp/stop.sh" > "$tmp/out" 2>&1; then
		echo "Cleanup of node $n ($ip) failed:" >&2
		cat "$tmp/out" >&2
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
	if ! run_on_node "$ip" "sudo -n bash -s" < "$tmp/node.sh" > "$tmp/out" 2>&1; then
		echo "Cleanup of node $n ($ip) failed:" >&2
		cat "$tmp/out" >&2
		rc=1
	fi
done

[ "$rc" -eq 0 ] && rm -f "$STATE_FILE"
exit "$rc"
