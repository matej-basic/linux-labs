#!/bin/bash
# ansible-01 setup: puts nodes 1 to 3 into the starting state. Prints
# nothing on success.
#
# Node 1 (control node): the SSH user of the lab configuration has no
# ~/ansible-lab, and its ~/.ssh and ~/.ansible are as they were at the
# first start (keys and known hosts from an earlier attempt go).
# Nodes 2 and 3 (managed nodes): a fresh user ansible with the password
# redhat and a sudoers drop-in that gives it sudo without a password;
# httpd is stopped and disabled and /var/www/html/index.html is gone.
#
# The first run records each node's package set (lib/packages.sh), and
# in /var/tmp/ansible-01.pre on each node what cleanup.sh puts back:
# on node 1 the file list of ~/.ssh, a copy of known_hosts and whether
# ~/.ansible existed; on nodes 2 and 3 the state of httpd and a copy of
# an existing index.html. The SSH user's authorized_keys and sudoers
# are never touched.
# No "set -u": load-config.sh reads variables that may be unset.
set -e

source /opt/linux-labs/lib/load-config.sh
source /opt/linux-labs/lib/packages.sh
load_lab_config

LAB=ansible-01
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
if [ "$SSH_USER" = ansible ] || [ "$SSH_USER" = root ]; then
	echo "$LAB needs an SSH user other than root and ansible, SSH_USER is $SSH_USER" >&2
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

# Node 1, the control node. Runs as root through "bash -s -- <user>",
# so every command that could read stdin gets /dev/null.
cat > "$tmp/control.sh" <<'REMOTE'
u=$1
pre=/var/tmp/ansible-01.pre
home=$(getent passwd "$u" | cut -d: -f6)
if [ -z "$home" ] || [ ! -d "$home" ]; then
	echo "the user $u has no home directory" >&2
	exit 1
fi

if [ ! -d "$pre" ]; then
	rm -rf "$pre.tmp"
	mkdir -m 0700 "$pre.tmp" || exit 1
	: > "$pre.tmp/flags"
	: > "$pre.tmp/ssh-files"
	if [ -d "$home/.ssh" ]; then
		echo ssh-dir >> "$pre.tmp/flags"
		ls -A "$home/.ssh" > "$pre.tmp/ssh-files" || exit 1
		if [ -f "$home/.ssh/known_hosts" ]; then
			cp -a "$home/.ssh/known_hosts" "$pre.tmp/known_hosts" || exit 1
		fi
	fi
	[ -e "$home/.ansible" ] && echo ansible-dir >> "$pre.tmp/flags"
	mv "$pre.tmp" "$pre" || exit 1
fi

# SSH connections that Ansible keeps open
pkill -u "$u" -f '\.ansible/cp/' </dev/null >/dev/null 2>&1

rm -rf --one-file-system "$home/ansible-lab"
grep -qx ansible-dir "$pre/flags" || rm -rf --one-file-system "$home/.ansible"
if [ -d "$home/.ssh" ]; then
	for f in "$home/.ssh"/* "$home/.ssh"/.[!.]*; do
		[ -e "$f" ] || [ -L "$f" ] || continue
		n=${f##*/}
		[ "$n" = authorized_keys ] && continue
		grep -qxF -- "$n" "$pre/ssh-files" || rm -rf -- "$f"
	done
	if [ -f "$pre/known_hosts" ]; then
		cp -a "$pre/known_hosts" "$home/.ssh/known_hosts" || exit 1
	fi
	grep -qx ssh-dir "$pre/flags" || rmdir "$home/.ssh" 2>/dev/null
fi
exit 0
REMOTE

# Nodes 2 and 3, the managed nodes
cat > "$tmp/managed.sh" <<'REMOTE'
pre=/var/tmp/ansible-01.pre
page=/var/www/html/index.html
mark="linux-labs ansible-01"

if [ ! -d "$pre" ]; then
	if getent passwd ansible >/dev/null &&
		[ "$(getent passwd ansible | cut -d: -f5)" != "$mark" ]; then
		echo "the user ansible already exists and was not created by the lab" >&2
		exit 1
	fi
	rm -rf "$pre.tmp"
	mkdir -m 0700 "$pre.tmp" || exit 1
	{
		systemctl is-enabled --quiet httpd 2>/dev/null && echo httpd-enabled
		systemctl is-active --quiet httpd 2>/dev/null && echo httpd-active
	} > "$pre.tmp/flags"
	if [ -f "$page" ]; then
		cp -a "$page" "$pre.tmp/index.html" || exit 1
	fi
	mv "$pre.tmp" "$pre" || exit 1
fi

if systemctl cat httpd </dev/null >/dev/null 2>&1; then
	systemctl disable --now httpd </dev/null >/dev/null 2>&1
fi
rm -f "$page"

# A fresh user ansible: remove the one of an earlier start first
if getent passwd ansible >/dev/null; then
	for i in 1 2 3 4 5; do
		pkill -KILL -u ansible </dev/null >/dev/null 2>&1
		sleep 1
		userdel -r ansible </dev/null >/dev/null 2>&1 && break
	done
	if getent passwd ansible >/dev/null; then
		echo "cannot remove the user ansible of an earlier start" >&2
		exit 1
	fi
fi
getent group ansible >/dev/null && groupdel ansible
useradd -m -c "$mark" ansible || exit 1
echo 'ansible:redhat' | chpasswd || exit 1

printf 'ansible ALL=(ALL) NOPASSWD: ALL\n' > /etc/sudoers.d/.ansible-01.tmp
chmod 0440 /etc/sudoers.d/.ansible-01.tmp
if ! visudo -cqf /etc/sudoers.d/.ansible-01.tmp; then
	rm -f /etc/sudoers.d/.ansible-01.tmp
	echo "the sudoers rule for ansible does not validate" >&2
	exit 1
fi
mv /etc/sudoers.d/.ansible-01.tmp /etc/sudoers.d/ansible-01 || exit 1
restorecon /etc/sudoers.d/ansible-01 >/dev/null 2>&1
exit 0
REMOTE

user_arg=$(printf '%q' "$SSH_USER")
for n in 1 2 3; do
	ip=$(get_node_ip "$n")
	if ! pkg_snapshot_node "$ip" "$LAB" > "$tmp/out" 2>&1; then
		echo "Recording the packages of node $n ($ip) failed:" >&2
		grep -v "^Warning: Permanently added" "$tmp/out" >&2
		exit 1
	fi
	if [ "$n" = 1 ]; then script="$tmp/control.sh"; else script="$tmp/managed.sh"; fi
	if ! run_on_node "$ip" "sudo -n bash -s -- $user_arg" < "$script" > "$tmp/out" 2>&1; then
		echo "Preparing node $n ($ip) failed:" >&2
		grep -v "^Warning: Permanently added" "$tmp/out" >&2
		exit 1
	fi
done

# The grader checks that the lab was started
mkdir -p "$STATE_DIR"
echo "nodes=$(get_node_ip 1) $(get_node_ip 2) $(get_node_ip 3)" > "$STATE_FILE"
chmod 0644 "$STATE_FILE"
