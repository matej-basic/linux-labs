#!/bin/bash
# clustering-01 setup: puts the three cluster nodes into the clean starting
# state (no cluster configuration, cluster services and httpd stopped and
# disabled, no index page, hacluster password locked) and removes
# Pacemaker, pcs and httpd, so the student installs them. The first run
# records each node's package set (lib/packages.sh) and in
# /var/tmp/clustering-01.pre and /var/tmp/clustering-01.bak the
# services, the firewall, the hacluster password and copies of the files
# and directories the lab touches, so that cleanup.sh can put them back.
# Prints nothing on success.
# No "set -u": load-config.sh reads variables that may be unset.
set -e

source /opt/linux-labs/lib/load-config.sh
source /opt/linux-labs/lib/packages.sh
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

# First run only: what the node looked like before the lab (the package
# set is in the package snapshot)
if [ ! -f "$pre" ]; then
	rm -rf "$bak"
	mkdir -p -m 0700 "$bak" || exit 1
	{
		for u in httpd pcsd pacemaker corosync; do
			systemctl is-enabled --quiet "$u" 2>/dev/null && echo "$u-enabled"
			systemctl is-active --quiet "$u" 2>/dev/null && echo "$u-active"
		done
		firewall-cmd --permanent --query-service=high-availability </dev/null >/dev/null 2>&1 && echo fw-ha
		if getent passwd hacluster >/dev/null; then
			echo user-hacluster
			getent shadow hacluster | cut -d: -f2 > "$bak/hacluster.shadow"
			getent shadow hacluster | cut -d: -f3 > "$bak/hacluster.lastchg"
		fi
	} > "$pre.tmp"
	for f in $files; do
		[ -f "$f" ] && cp -a "$f" "$bak/$(basename "$f")"
	done
	for d in $dirs; do
		if [ -d "$d" ]; then
			tar --selinux --xattrs --acls -C / -cpf "$bak/$(echo "${d#/}" | tr / _).tar" "${d#/}" || exit 1
		fi
	done
	# Web directories that no package owns (left over from an earlier
	# install): cleanup.sh puts them back as they are now
	for d in /etc/httpd /var/log/httpd /var/www; do
		if [ -d "$d" ] && ! rpm -qf "$d" >/dev/null 2>&1; then
			mkdir -p "$bak/dirs$(dirname "$d")" && cp -a "$d" "$bak/dirs$d" || exit 1
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

# The student installs Pacemaker, pcs and httpd; cleanup.sh installs
# again the ones that were there before the lab
for p in pcs pacemaker corosync httpd; do
	if rpm -q "$p" >/dev/null 2>&1; then
		dnf -y remove "$p" </dev/null >/dev/null 2>&1 || exit 1
	fi
done
rm -f /var/www/html/index.html /etc/httpd/conf/httpd.conf.rpmsave /etc/corosync/corosync.conf.rpmsave

if getent passwd hacluster >/dev/null; then
	passwd -l hacluster >/dev/null 2>&1
fi
exit 0
REMOTE

for n in 1 2 3; do
	ip=$(get_node_ip "$n")
	if ! pkg_snapshot_node "$ip" "$LAB" > "$tmp/out" 2>&1; then
		echo "Recording the packages of node $n ($ip) failed:" >&2
		cat "$tmp/out" >&2
		exit 1
	fi
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
