#!/bin/bash
# clustering-02 setup: puts the three nodes into the end state of
# clustering-01 (cluster ha_cluster running on all nodes, resource
# apache_web started, fencing disabled) without fence agent or fence
# devices.
#
# If node 1 already runs a cluster with the resource apache_web (a student
# who just finished clustering-01), that cluster is used and only the fence
# parts are reset. Otherwise setup builds the cluster itself, the same way
# as the clustering-01 solution. Either way the first run records the state
# of every node in /var/tmp/clustering-02.pre and backs up the files and
# directories the lab touches in /var/tmp/clustering-02.bak, so that
# cleanup.sh puts back exactly what this lab changed. The line "built" in
# the .pre file marks a node whose cluster this lab built.
#
# Building the cluster takes a few minutes. Prints nothing on success.
# No "set -u": load-config.sh reads variables that may be unset.
set -e

source /opt/linux-labs/lib/load-config.sh
load_lab_config

LAB=clustering-02
STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/$LAB"
HA_PASS=LabPass-2024

if [ "$NODES_ENABLED" != "true" ]; then
	echo "$LAB needs multi-node labs: run 'sudo labctl configure interactive' and enable them" >&2
	exit 1
fi
if ! [ "$NODE_COUNT" -ge 3 ] 2>/dev/null; then
	echo "$LAB needs 3 nodes, NODE_COUNT is $NODE_COUNT: run 'sudo labctl configure set NODE_COUNT 3'" >&2
	exit 1
fi

N1=$(get_node_ip 1)
N2=$(get_node_ip 2)
N3=$(get_node_ip 3)
ALL="$N1 $N2 $N3"

for ip in $ALL; do
	if ! test_node_connectivity "$ip" >/dev/null; then
		echo "Cannot reach node $ip over SSH as $SSH_USER" >&2
		exit 1
	fi
done

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# fail <message>: print the message and the output of the last step
fail() {
	echo "$LAB setup: $1" >&2
	[ -s "$tmp/out" ] && cat "$tmp/out" >&2
	exit 1
}

# n1 <command>: run a command on node 1, no standard input
n1() {
	run_on_node "$N1" "$1" </dev/null
}

# A cluster with apache_web on node 1, which this lab did not build
cluster_ok() {
	n1 "sudo -n cibadmin -Q --xpath \"//primitive[@id='apache_web']\"" >/dev/null 2>&1
}

# Record the pre-lab state of every node (first run only). The argument
# "built" marks the node as one whose cluster this lab builds.
cat > "$tmp/record.sh" <<'REMOTE'
pre=/var/tmp/clustering-02.pre
bak=/var/tmp/clustering-02.bak
files="/var/www/html/index.html /etc/httpd/conf/httpd.conf"
dirs="/etc/corosync /var/lib/pacemaker /var/lib/corosync /var/lib/pcsd /var/log/pacemaker /var/log/cluster /var/log/pcsd"

if [ ! -f "$pre" ]; then
	rm -rf "$bak"
	mkdir -p -m 0700 "$bak" || exit 1
	{
		[ "$1" = built ] && echo built
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
	# Every installed package, so cleanup.sh removes what the lab added
	# and downgrades what it upgraded
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
exit 0
REMOTE

# Build the clustering-01 node state: old cluster files gone, packages,
# firewall, hacluster password, pcsd, index page, httpd disabled
cat > "$tmp/node.sh" <<'REMOTE'
if command -v pcs >/dev/null 2>&1; then
	pcs cluster destroy </dev/null >/dev/null 2>&1
fi
systemctl disable --now pacemaker corosync httpd </dev/null >/dev/null 2>&1
pkill -x httpd >/dev/null 2>&1
rm -f /etc/corosync/corosync.conf /etc/corosync/authkey
rm -f /var/lib/pcsd/known-hosts /var/lib/pcsd/tokens /var/lib/pcsd/pcs_settings.conf /var/lib/pcsd/pcs_users.conf
rm -rf /var/lib/pacemaker/cib/* /var/lib/pacemaker/pengine/* /var/lib/corosync/*

. /etc/os-release
if [ "${VERSION_ID%%.*}" = 8 ]; then repo=ha; else repo=highavailability; fi
dnf -y install --enablerepo="$repo" pacemaker pcs httpd </dev/null || exit 1
firewall-cmd --permanent --add-service=high-availability </dev/null || exit 1
firewall-cmd --reload </dev/null || exit 1
echo "hacluster:$1" | chpasswd || exit 1
systemctl enable --now pcsd </dev/null || exit 1
echo "HA Cluster - $(uname -n)" > /var/www/html/index.html || exit 1
restorecon /var/www/html/index.html
systemctl disable httpd </dev/null >/dev/null 2>&1
exit 0
REMOTE

# Remove the fence agent where the lab added it (the recorded package list
# says what was there before)
cat > "$tmp/unfence.sh" <<'REMOTE'
bak=/var/tmp/clustering-02.bak
if rpm -q fence-agents-virsh >/dev/null 2>&1 &&
	! grep -q '^fence-agents-virsh\.' "$bak/rpms" 2>/dev/null; then
	dnf -y remove fence-agents-virsh </dev/null || exit 1
fi
exit 0
REMOTE

# A rerun keeps the mode of the first run
mode=""
[ -f "$STATE_FILE" ] && mode=$(sed -n 's/^mode=//p' "$STATE_FILE")
if [ -z "$mode" ]; then
	if cluster_ok; then mode=existing; else mode=built; fi
fi
rec_arg=""
[ "$mode" = built ] && rec_arg=built

for ip in $ALL; do
	run_on_node "$ip" "sudo -n bash -s $rec_arg" < "$tmp/record.sh" > "$tmp/out" 2>&1 ||
		fail "recording the state of node $ip failed"
done

# The state file goes first, so that cleanup.sh also undoes a setup that
# fails halfway
mkdir -p "$STATE_DIR"
printf 'mode=%s\nnodes=%s\n' "$mode" "$ALL" > "$STATE_FILE"
chmod 0644 "$STATE_FILE"

if [ "$mode" = built ] && ! cluster_ok; then
	for ip in $ALL; do
		run_on_node "$ip" "sudo -n bash -s $HA_PASS" < "$tmp/node.sh" > "$tmp/out" 2>&1 ||
			fail "preparing node $ip failed"
	done
	H1=$(n1 "uname -n") || fail "cannot read the host name of node 1"
	H2=$(run_on_node "$N2" "uname -n" </dev/null) || fail "cannot read the host name of node 2"
	H3=$(run_on_node "$N3" "uname -n" </dev/null) || fail "cannot read the host name of node 3"
	NODES="$H1 addr=$N1 $H2 addr=$N2 $H3 addr=$N3"
	n1 "sudo -n pcs host auth $NODES -u hacluster -p $HA_PASS" > "$tmp/out" 2>&1 ||
		fail "pcs host auth failed"
	n1 "sudo -n pcs cluster setup ha_cluster $NODES --start --enable" > "$tmp/out" 2>&1 ||
		fail "pcs cluster setup failed"
	quorate=no
	for _ in $(seq 90); do
		if [ "$(n1 "sudo -n crm_node -q" 2>/dev/null)" = 1 ]; then
			quorate=yes
			break
		fi
		sleep 2
	done
	[ "$quorate" = yes ] || fail "the new cluster did not reach quorum"
	n1 "sudo -n pcs property set stonith-enabled=false" > "$tmp/out" 2>&1 ||
		fail "cannot disable STONITH"
	n1 "sudo -n pcs resource create apache_web ocf:heartbeat:apache configfile=/etc/httpd/conf/httpd.conf op monitor interval=1min" > "$tmp/out" 2>&1 ||
		fail "cannot create the resource apache_web"
fi

# Fence parts of a previous run or of the solution: fencing off first, so
# that the cluster never runs with fencing on and no device
n1 "sudo -n pcs property set stonith-enabled=false" > "$tmp/out" 2>&1 ||
	fail "cannot disable STONITH on node 1 ($N1)"
for id in stonith-node1 stonith-node2 stonith-node3; do
	n1 "sudo -n pcs stonith delete $id" >/dev/null 2>&1 || true
done
n1 "sudo -n pcs resource cleanup" >/dev/null 2>&1 || true
for ip in $ALL; do
	run_on_node "$ip" "sudo -n bash -s" < "$tmp/unfence.sh" > "$tmp/out" 2>&1 ||
		fail "removing fence-agents-virsh from node $ip failed"
done

# apache_web must be started before the student begins (up to 2 minutes)
started=no
for _ in $(seq 60); do
	if n1 "sudo -n crm_mon -1 -r" 2>/dev/null | grep -Eq 'apache_web.*Started'; then
		started=yes
		break
	fi
	sleep 2
done
[ "$started" = yes ] || fail "the resource apache_web did not start"
exit 0
