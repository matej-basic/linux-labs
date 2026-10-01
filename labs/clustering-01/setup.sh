#!/bin/bash
# clustering-01 setup: puts the three cluster nodes into the clean starting
# state (no cluster configuration, cluster services and httpd stopped and
# disabled, no index page, hacluster password locked). Packages that were
# already installed before the lab stay installed; the first run records
# the state of every node in /var/tmp/clustering-01.pre and backs up the
# files and directories the lab touches in /var/tmp/clustering-01.bak, so
# that cleanup.sh can put it back. Prints nothing on success.
# No "set -u": load-config.sh reads variables that may be unset.
set -e

source /opt/linux-labs/lib/load-config.sh
load_lab_config

LAB=clustering-01
STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/$LAB"

if [ "$NODES_ENABLED" != "true" ]; then
	echo "$LAB needs multi-node labs: run 'sudo labctl configure interactive' and enable them" >&2
	exit 1
fi
if ! [ "$NODE_COUNT" -ge 3 ] 2>/dev/null; then
	echo "$LAB needs 3 nodes, NODE_COUNT is $NODE_COUNT: run 'sudo labctl configure set NODE_COUNT 3'" >&2
	exit 1
fi

for n in 1 2 3; do
	ip=$(get_node_ip "$n")
	if ! test_node_connectivity "$ip" >/dev/null; then
		echo "Cannot reach node $n ($ip) over SSH as $SSH_USER" >&2
		exit 1
	fi
done

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Remote reset, run as root on every node through "bash -s", so every
# command that could read stdin gets /dev/null instead of the script.
cat > "$tmp/node.sh" <<'REMOTE'
pre=/var/tmp/clustering-01.pre
bak=/var/tmp/clustering-01.bak
files="/var/www/html/index.html /etc/httpd/conf/httpd.conf"
dirs="/etc/corosync /var/lib/pacemaker /var/lib/corosync /var/lib/pcsd /var/log/pacemaker /var/log/cluster /var/log/pcsd"

# First run only: what the node looked like before the lab
if [ ! -f "$pre" ]; then
	rm -rf "$bak"
	mkdir -p -m 0700 "$bak" || exit 1
	{
		for p in httpd pacemaker corosync pcs; do
			rpm -q "$p" >/dev/null 2>&1 && echo "$p-installed"
		done
		for u in httpd pcsd pacemaker corosync; do
			systemctl is-enabled --quiet "$u" 2>/dev/null && echo "$u-enabled"
			systemctl is-active --quiet "$u" 2>/dev/null && echo "$u-active"
		done
		firewall-cmd --permanent --query-service=high-availability </dev/null >/dev/null 2>&1 && echo fw-ha
		getent group haclient >/dev/null && echo group-haclient
		if getent passwd hacluster >/dev/null; then
			echo user-hacluster
			getent shadow hacluster | cut -d: -f2 > "$bak/hacluster.shadow"
			getent shadow hacluster | cut -d: -f3 > "$bak/hacluster.lastchg"
		fi
	} > "$pre.tmp"
	# Installing pacemaker upgrades its libraries where they are already
	# installed; cleanup.sh downgrades them back to these versions
	rpm -qa --qf '%{NAME}.%{ARCH} %{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n' |
		sort > "$bak/rpms" || exit 1
	for f in $files; do
		[ -f "$f" ] && cp -a "$f" "$bak/$(basename "$f")"
	done
	for d in $dirs; do
		if [ -d "$d" ]; then
			tar --selinux --xattrs --acls -C / -cpf "$bak/$(echo "${d#/}" | tr / _).tar" "${d#/}" || exit 1
		fi
	done
	chmod 0600 "$pre.tmp"
	mv "$pre.tmp" "$pre" || exit 1
fi

# No cluster: "pcs cluster destroy" stops the services and removes the
# configuration; without pcs the files go by hand
if command -v pcs >/dev/null 2>&1; then
	pcs cluster destroy </dev/null >/dev/null 2>&1
fi
systemctl disable --now pacemaker corosync pcsd httpd </dev/null >/dev/null 2>&1
pkill -x httpd >/dev/null 2>&1
rm -f /etc/corosync/corosync.conf /etc/corosync/authkey
rm -f /var/lib/pcsd/known-hosts /var/lib/pcsd/tokens /var/lib/pcsd/pcs_settings.conf /var/lib/pcsd/pcs_users.conf
rm -rf /var/lib/pacemaker/cib/* /var/lib/pacemaker/pengine/* /var/lib/corosync/*

# Packages the lab or an earlier attempt installed go
remove=""
for p in pcs pacemaker corosync httpd; do
	if rpm -q "$p" >/dev/null 2>&1 && ! grep -qx "$p-installed" "$pre"; then
		remove="$remove $p"
	fi
done
if [ -n "$remove" ]; then
	# shellcheck disable=SC2086 # word splitting is intended
	dnf -y remove $remove </dev/null >/dev/null 2>&1 || exit 1
fi

rm -f /var/www/html/index.html /etc/httpd/conf/httpd.conf.rpmsave
b="$bak/httpd.conf"
if [ -f "$b" ] && [ -d /etc/httpd/conf ]; then
	cp -a "$b" /etc/httpd/conf/httpd.conf && restorecon /etc/httpd/conf/httpd.conf 2>/dev/null
fi

if getent passwd hacluster >/dev/null; then
	passwd -l hacluster >/dev/null 2>&1
fi
exit 0
REMOTE

for n in 1 2 3; do
	ip=$(get_node_ip "$n")
	if ! run_on_node "$ip" "sudo -n bash -s" < "$tmp/node.sh" > "$tmp/out" 2>&1; then
		echo "Preparing node $n ($ip) failed:" >&2
		cat "$tmp/out" >&2
		exit 1
	fi
done

# The grader checks that the lab was started
mkdir -p "$STATE_DIR"
echo "nodes=$(get_node_ip 1) $(get_node_ip 2) $(get_node_ip 3)" > "$STATE_FILE"
chmod 0644 "$STATE_FILE"
