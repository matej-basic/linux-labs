#!/bin/bash
# clustering-03 cleanup: undoes what setup.sh and the solution changed on
# the nodes, using the package snapshot of the first start
# (lib/packages.sh), the state that the first setup.sh run recorded in
# /var/tmp/clustering-03.pre and /var/tmp/clustering-03.bak and the
# previous no-quorum-policy value in the state file.
#
# A node whose cluster setup.sh built ("built" in the .pre file) loses the
# cluster again. The cluster directories that did not exist before the
# lab go first, so that the hacluster account and the haclient group own
# no file; then the package set of the first start comes back, which
# removes Pacemaker, pcs and httpd where the lab installed them, together
# with the accounts they created. The index page, the httpd
# configuration, the cluster directories, the hacluster password, the
# services and the high-availability firewall service go back to their
# recorded values.
#
# A cluster that existed before the lab (from clustering-01 or -02) stays:
# corosync.conf goes back to its recorded copy on every node, the changed
# nodes restart one at a time so that the cluster keeps quorum, and
# no-quorum-policy gets its previous value again. When the cluster or a
# node cannot be restored, the records stay for the next reset and the
# exit status is 1.
# No "set -u": load-config.sh reads variables that may be unset.

source /opt/linux-labs/lib/load-config.sh
source /opt/linux-labs/lib/packages.sh
load_lab_config

LAB=clustering-03
STATE_FILE="/opt/linux-labs/state/$LAB"

# Nothing was started without multi-node support
if [ "$NODES_ENABLED" != "true" ] || ! [ "$NODE_COUNT" -ge 3 ] 2>/dev/null; then
	rm -f "$STATE_FILE"
	exit 0
fi

N1=$(get_node_ip 1)
ALL="$N1 $(get_node_ip 2) $(get_node_ip 3)"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

mode=""
nqp=""
if [ -f "$STATE_FILE" ]; then
	mode=$(sed -n 's/^mode=//p' "$STATE_FILE")
	nqp=$(sed -n 's/^nqp=//p' "$STATE_FILE")
fi
if [ -z "$mode" ]; then
	if run_on_node "$N1" "sudo -n grep -qx built /var/tmp/$LAB.pre" </dev/null >/dev/null 2>&1; then
		mode=built
	elif run_on_node "$N1" "sudo -n test -f /var/tmp/$LAB.pre" </dev/null >/dev/null 2>&1; then
		mode=existing
	fi
fi

# members_ok <ip>: the node sees 3 cluster members (up to 2 minutes)
members_ok() {
	for _ in $(seq 60); do
		run_on_node "$1" "sudo -n corosync-quorumtool -s" </dev/null 2>/dev/null |
			grep -Eq '^Nodes:[[:space:]]+3$' && return 0
		sleep 2
	done
	return 1
}

rc=0

# A cluster that existed before the lab: the recorded corosync.conf comes
# back; exit 3 if the file changed
cat > "$tmp/conf.sh" <<'REMOTE'
conf=/etc/corosync/corosync.conf
b=/var/tmp/clustering-03.bak/corosync.conf
[ -f "$b" ] || exit 0
cmp -s "$b" "$conf" && exit 0
cp -a "$b" "$conf" || exit 1
restorecon "$conf" 2>/dev/null
exit 3
REMOTE

if [ "$mode" = existing ]; then
	for ip in $ALL; do
		r=0
		run_on_node "$ip" "sudo -n bash -s" < "$tmp/conf.sh" > "$tmp/out" 2>&1 || r=$?
		case "$r" in
		0) continue ;;
		3) ;;
		*)
			echo "Restoring corosync.conf on node $ip failed:" >&2
			cat "$tmp/out" >&2
			rc=1
			continue
			;;
		esac
		# One node at a time, the next one only with 3 members again
		run_on_node "$ip" "sudo -n systemctl stop pacemaker corosync && sudo -n systemctl start pacemaker" </dev/null >/dev/null 2>&1
		for n in $ALL; do
			if ! members_ok "$n"; then
				echo "The cluster did not re-form after restarting node $ip" >&2
				rc=1
				break
			fi
		done
	done

	# The previous value of no-quorum-policy (retry while the cluster
	# elects a DC)
	if [ "$nqp" = unset ] || [ -z "$nqp" ]; then
		cmd="sudo -n crm_attribute --type crm_config --name no-quorum-policy --delete"
	else
		cmd="sudo -n pcs property set no-quorum-policy=$nqp"
	fi
	ok=no
	for _ in $(seq 30); do
		if run_on_node "$N1" "$cmd" </dev/null >/dev/null 2>&1; then
			ok=yes
			break
		fi
		sleep 2
	done
	if [ "$ok" != yes ]; then
		echo "Cannot restore the cluster property no-quorum-policy on node 1 ($N1)" >&2
		rc=1
	fi
fi

# Before the package restore: on a node whose cluster this lab built,
# destroy the cluster, stop the services and remove the lab files and the
# cluster directories that setup.sh did not record
cat > "$tmp/stop.sh" <<'REMOTE'
pre=/var/tmp/clustering-03.pre
bak=/var/tmp/clustering-03.bak
dirs="/etc/corosync /var/lib/pacemaker /var/lib/corosync /var/lib/pcsd /var/log/pacemaker /var/log/cluster /var/log/pcsd"

# setup.sh never ran on this node: nothing to undo
[ -f "$pre" ] || exit 0

if grep -qx built "$pre"; then
	if command -v pcs >/dev/null 2>&1; then
		pcs cluster destroy </dev/null >/dev/null 2>&1
	fi
	systemctl disable --now pacemaker corosync pcsd httpd </dev/null >/dev/null 2>&1
	pkill -x httpd >/dev/null 2>&1
	rm -f /var/www/html/index.html /etc/httpd/conf/httpd.conf.rpmsave /etc/corosync/corosync.conf.rpmsave
	for d in $dirs; do
		[ -f "$bak/$(echo "${d#/}" | tr / _).tar" ] || rm -rf "$d"
	done
fi

# rpcbind, which the resource agents pull in through nfs-utils, creates
# the rpc account. Where the account is new since the package snapshot,
# the NFS helper services stop and the account's files go too.
accounts=/opt/linux-labs/state/clustering-03.packages/accounts
if [ -s "$accounts" ] && getent passwd rpc >/dev/null && ! grep -qx user:rpc "$accounts"; then
	systemctl stop rpc-statd-notify rpcbind.socket rpcbind </dev/null >/dev/null 2>&1
	rm -rf /var/lib/rpcbind
fi
exit 0
REMOTE

# After the package restore: on a node whose cluster this lab built the
# directories, files, password, services and firewall
cat > "$tmp/node.sh" <<'REMOTE'
pre=/var/tmp/clustering-03.pre
bak=/var/tmp/clustering-03.bak
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

if had built; then
	rm -f /etc/httpd/conf/httpd.conf.rpmsave /etc/corosync/corosync.conf.rpmsave
	if ! rpm -q httpd >/dev/null 2>&1; then
		undir /etc/httpd
		undir /var/log/httpd
		undir /var/www
	fi

	# Cluster directories: the recorded copy where there was one, else
	# gone unless a package owns them
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
fi

rm -rf "$pre" "$bak"
exit 0
REMOTE

# The records stay when the cluster could not be restored, so that a
# second reset can try again
if [ "$rc" -eq 0 ]; then
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
fi

[ "$rc" -eq 0 ] && rm -f "$STATE_FILE"
exit "$rc"
