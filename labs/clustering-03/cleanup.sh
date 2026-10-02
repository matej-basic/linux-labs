#!/bin/bash
# clustering-03 cleanup: undoes what setup.sh and the solution changed on
# the nodes, using the state that the first setup.sh run recorded in
# /var/tmp/clustering-03.pre and /var/tmp/clustering-03.bak and the
# previous no-quorum-policy value in the state file.
#
# A node whose cluster setup.sh built ("built" in the .pre file) loses the
# cluster again: pacemaker, pcs and everything else the lab installed are
# removed, upgraded packages go back to their recorded version, and the
# index page, the httpd configuration, the cluster directories, the
# hacluster password, the services and the high-availability firewall
# service go back to their recorded values.
#
# A cluster that existed before the lab (from clustering-01 or -02) stays:
# corosync.conf goes back to its recorded copy on every node, the changed
# nodes restart one at a time so that the cluster keeps quorum, and
# no-quorum-policy gets its previous value again.
# No "set -u": load-config.sh reads variables that may be unset.

source /opt/linux-labs/lib/load-config.sh
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

cat > "$tmp/node.sh" <<'REMOTE'
pre=/var/tmp/clustering-03.pre
bak=/var/tmp/clustering-03.bak
dirs="/etc/corosync /var/lib/pacemaker /var/lib/corosync /var/lib/pcsd /var/log/pacemaker /var/log/cluster /var/log/pcsd"

# setup.sh never ran on this node: nothing to undo
[ -f "$pre" ] || exit 0

had() {
	grep -qx "$1" "$pre"
}

# rmunowned <dir>: remove a directory that no installed package owns
rmunowned() {
	[ -d "$1" ] || return 0
	rpm -qf "$1" >/dev/null 2>&1 || rm -rf "$1"
}

if had built; then
	if command -v pcs >/dev/null 2>&1; then
		pcs cluster destroy </dev/null >/dev/null 2>&1
	fi
	systemctl disable --now pacemaker corosync pcsd httpd </dev/null >/dev/null 2>&1
	pkill -x httpd >/dev/null 2>&1
	rm -f /var/www/html/index.html /etc/httpd/conf/httpd.conf.rpmsave
fi

# Packages the lab added go; packages it upgraded go back to the recorded
# version (one name.arch per list only, so kernels and other
# multi-version packages are left alone). The old version may have left
# the repositories, so a failed downgrade does not fail cleanup.
if [ -f "$bak/rpms" ]; then
	rpm -qa --qf '%{NAME}.%{ARCH} %{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n' | sort > "$bak/rpms.now"
	new=$(awk 'NR == FNR { n[$1] = 1; next } !($1 in n) { print $1 }' "$bak/rpms" "$bak/rpms.now")
	if [ -n "$new" ]; then
		# shellcheck disable=SC2086 # word splitting is intended
		dnf -y remove $new </dev/null >/dev/null 2>&1 || exit 1
	fi
	rpm -qa --qf '%{NAME}.%{ARCH} %{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n' | sort > "$bak/rpms.now"
	old=$(awk 'NR == FNR { n[$1]++; v[$1] = $2; next }
		{ m[$1]++; w[$1] = $2 }
		END { for (k in v) if (n[k] == 1 && m[k] == 1 && v[k] != w[k]) print v[k] }' \
		"$bak/rpms" "$bak/rpms.now")
	if [ -n "$old" ]; then
		repos=$(dnf -q repolist --all </dev/null 2>/dev/null |
			awk '$1 == "ha" || $1 == "highavailability" { printf " --enablerepo=%s", $1 }')
		# shellcheck disable=SC2086 # word splitting is intended
		dnf -y $repos downgrade $old </dev/null >/dev/null 2>&1
	fi
fi

if had built; then
	if ! had httpd-installed; then
		rmunowned /etc/httpd
		rmunowned /var/log/httpd
		rmunowned /var/www
	fi

	# Cluster directories: the recorded copy where there was one, else
	# gone unless a package still owns them
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

	# The hacluster account: the recorded password field, or no account
	if had user-hacluster; then
		if [ -f "$bak/hacluster.shadow" ] && getent passwd hacluster >/dev/null; then
			usermod -p "$(cat "$bak/hacluster.shadow")" hacluster || exit 1
			lastchg=$(cat "$bak/hacluster.lastchg" 2>/dev/null)
			[ -n "$lastchg" ] && chage -d "$lastchg" hacluster
		fi
	else
		getent passwd hacluster >/dev/null && userdel hacluster
		if ! had group-haclient && getent group haclient >/dev/null; then
			groupdel haclient
		fi
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

# The backups stay when the cluster could not be restored, so that a
# second reset can try again
if [ "$rc" -eq 0 ]; then
	for n in 1 2 3; do
		ip=$(get_node_ip "$n")
		if ! run_on_node "$ip" "sudo -n bash -s" < "$tmp/node.sh" > "$tmp/out" 2>&1; then
			echo "Cleanup of node $n ($ip) failed:" >&2
			cat "$tmp/out" >&2
			rc=1
		fi
	done
fi

[ "$rc" -eq 0 ] && rm -f "$STATE_FILE"
exit "$rc"
