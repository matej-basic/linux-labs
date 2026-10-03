#!/bin/bash
# git-01 setup: checks that node 1 has no user or group git, no
# /home/git and no /srv/git, and that node 2 has no ~/project for the
# node account, since the lab creates all of them and removes them at
# reset. Node 2 gets the key ~/.ssh/id_ed25519 for the node account (an
# existing key there is used as it is). The existing key logins stay as
# they are.
#
# Each node keeps in /var/tmp/git-01.pre what existed before the lab:
# node 1 a copy of /etc/shells, node 2 the flags for the key, the
# ~/.ssh directory, the known_hosts files and a copy of ~/.gitconfig.
# The package set of both nodes goes to the snapshot of lib/packages.sh.
# A restart first runs cleanup.sh, so every start begins from the state
# before the lab. Prints nothing on success.
# No "set -u": load-config.sh reads variables that may be unset.
set -e

source /opt/linux-labs/lib/load-config.sh
source /opt/linux-labs/lib/packages.sh
load_lab_config

LAB=git-01
STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/$LAB"

if [ "$NODES_ENABLED" != "true" ]; then
	echo "$LAB needs multi-node labs: run 'sudo labctl configure interactive' and enable them" >&2
	exit 1
fi
if [ "$NODE_COUNT" -lt 2 ] 2>/dev/null; then
	echo "$LAB needs 2 nodes, NODE_COUNT is $NODE_COUNT: run 'sudo labctl configure set NODE_COUNT 2'" >&2
	exit 1
fi

N1=$(get_node_ip 1)
N2=$(get_node_ip 2)
for n in 1 2; do
	ip=$(get_node_ip "$n")
	if ! test_node_connectivity "$ip" >/dev/null; then
		echo "Cannot reach node $n ($ip) over SSH as $SSH_USER" >&2
		exit 1
	fi
done

# Undo an earlier start and its solution first. cleanup.sh does nothing
# on a node without records.
if ! bash "$(dirname "$0")/cleanup.sh"; then
	echo "Undoing an earlier start of $LAB failed." >&2
	exit 1
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

cat > "$tmp/node1.sh" <<'REMOTE'
pre=/var/tmp/git-01.pre
[ -d "$pre" ] && exit 0
if getent passwd git >/dev/null; then
	echo "the user git exists already, the lab creates it" >&2
	exit 1
fi
if getent group git >/dev/null; then
	echo "the group git exists already, the lab creates it" >&2
	exit 1
fi
for p in /home/git /srv/git; do
	if [ -e "$p" ]; then
		echo "$p exists already, the lab creates it" >&2
		exit 1
	fi
done
rm -rf "$pre.tmp"
mkdir -m 0700 "$pre.tmp" || exit 1
cp -a /etc/shells "$pre.tmp/shells" || exit 1
mv "$pre.tmp" "$pre" || exit 1
exit 0
REMOTE

cat > "$tmp/node2.sh" <<'REMOTE'
pre=/var/tmp/git-01.pre
home=$(getent passwd "$LABU" | cut -d: -f6)
if [ -z "$home" ] || [ ! -d "$home" ]; then
	echo "user $LABU has no home directory" >&2
	exit 1
fi
key="$home/.ssh/id_ed25519"
khu="$home/.ssh/known_hosts"
khr=/root/.ssh/known_hosts

has_host() {
	[ -f "$1" ] && ssh-keygen -F "$N1" -f "$1" >/dev/null 2>&1
}

if [ ! -d "$pre" ]; then
	if [ -e "$home/project" ]; then
		echo "$home/project exists already, the lab creates it" >&2
		exit 1
	fi
	rm -rf "$pre.tmp"
	mkdir -m 0700 "$pre.tmp" || exit 1
	{
		[ -e "$key" ] && echo key-existed
		[ -e "$home/.ssh" ] && echo sshdir-existed
		[ -e "$khu" ] && echo khu-existed
		[ -e "$khu.old" ] && echo khu-old-existed
		has_host "$khu" && echo khu-host
		[ -e "$khr" ] && echo khr-existed
		[ -e "$khr.old" ] && echo khr-old-existed
		has_host "$khr" && echo khr-host
		[ -e "$home/.gitconfig" ] && echo gitconfig-existed
	} > "$pre.tmp/flags"
	if [ -f "$home/.gitconfig" ]; then
		cp -a "$home/.gitconfig" "$pre.tmp/gitconfig" || exit 1
	fi
	mv "$pre.tmp" "$pre" || exit 1
fi

if ! grep -qx key-existed "$pre/flags"; then
	rm -f "$key" "$key.pub"
	runuser -u "$LABU" -- mkdir -p -m 0700 "$home/.ssh" || exit 1
	runuser -u "$LABU" -- ssh-keygen -q -t ed25519 -N '' -C git-01-lab \
		-f "$key" </dev/null >/dev/null || exit 1
	restorecon -R "$home/.ssh" 2>/dev/null
fi
if [ ! -f "$key.pub" ]; then
	echo "$key exists, but $key.pub is missing" >&2
	exit 1
fi
exit 0
REMOTE

# send <node> <script>: run the script as root on the node
send() {
	{
		printf "LABU='%s'; N1='%s'\n" "$SSH_USER" "$N1"
		cat "$tmp/$2"
	} | run_on_node "$1" "sudo -n bash -s"
}

n=0
for ip in "$N1" "$N2"; do
	n=$((n + 1))
	if ! send "$ip" "node$n.sh" > /dev/null 2> "$tmp/err"; then
		echo "Preparing node $n ($ip) failed:" >&2
		grep -v "^Warning: Permanently added" "$tmp/err" >&2
		exit 1
	fi
	if ! pkg_snapshot_node "$ip" "$LAB" > "$tmp/out" 2>&1; then
		echo "Recording the packages of node $n ($ip) failed:" >&2
		cat "$tmp/out" >&2
		exit 1
	fi
done

mkdir -p "$STATE_DIR"
printf 'node1=%s\nnode2=%s\n' "$N1" "$N2" > "$STATE_FILE"
chmod 0644 "$STATE_FILE"
