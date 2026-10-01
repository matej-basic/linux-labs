#!/bin/bash
# clustering-01 cleanup: destroys the cluster and puts every node back
# into the state that the first setup.sh run recorded. Pacemaker, corosync,
# pcs and httpd are removed where setup.sh found them missing; the index
# page, the httpd configuration, the cluster directories, the hacluster
# password, the boot and running state of the services and the
# high-availability firewall service go back to their recorded values.
# No "set -u": load-config.sh reads variables that may be unset.

source /opt/linux-labs/lib/load-config.sh
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

cat > "$tmp/node.sh" <<'REMOTE'
pre=/var/tmp/clustering-01.pre
bak=/var/tmp/clustering-01.bak
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

if command -v pcs >/dev/null 2>&1; then
	pcs cluster destroy </dev/null >/dev/null 2>&1
fi
systemctl disable --now pacemaker corosync pcsd httpd </dev/null >/dev/null 2>&1
pkill -x httpd >/dev/null 2>&1
rm -f /var/www/html/index.html /etc/httpd/conf/httpd.conf.rpmsave

remove=""
for p in pcs pacemaker corosync httpd; do
	if rpm -q "$p" >/dev/null 2>&1 && ! had "$p-installed"; then
		remove="$remove $p"
	fi
done
if [ -n "$remove" ]; then
	# shellcheck disable=SC2086 # word splitting is intended
	dnf -y remove $remove </dev/null >/dev/null 2>&1 || exit 1
fi
# Packages that were installed before and have been upgraded since go
# back to the recorded version (one name.arch per list only, so kernels
# and other multi-version packages are left alone). The old version may
# have left the repositories, so a failed downgrade does not fail cleanup.
if [ -f "$bak/rpms" ]; then
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

if ! had httpd-installed; then
	rmunowned /etc/httpd
	rmunowned /var/log/httpd
	rmunowned /var/www
fi

# Cluster directories: the recorded copy where there was one, else gone
# unless a package still owns them
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

rm -rf "$pre" "$bak"
exit 0
REMOTE

rc=0
for n in 1 2 3; do
	ip=$(get_node_ip "$n")
	if ! run_on_node "$ip" "sudo -n bash -s" < "$tmp/node.sh" > "$tmp/out" 2>&1; then
		echo "Cleanup of node $n ($ip) failed:" >&2
		cat "$tmp/out" >&2
		rc=1
	fi
done

[ "$rc" -eq 0 ] && rm -f "$STATE_FILE"
exit "$rc"
