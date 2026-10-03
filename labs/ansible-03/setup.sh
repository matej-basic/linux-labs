#!/bin/bash
# ansible-03 setup: puts nodes 1 to 3 into the end state of ansible-01
# without the playbook, with the inventory group appservers. Prints
# nothing on success.
#
# Node 1 (control node): ansible-core is installed. The SSH user of the
# lab configuration has ~/ansible-lab with ansible.cfg and inventory
# only, the key pair ~/.ssh/ansible_lab, the host keys of nodes 2 and 3
# in ~/.ssh/known_hosts and the file ~/appadmin-password.txt (mode
# 0600) with a new random password for the user appadmin. Its ~/.ssh
# and ~/.ansible are otherwise as they were at the first start.
# Nodes 2 and 3 (managed nodes): a fresh user ansible with the password
# redhat, the public key of node 1 in its authorized_keys and a sudoers
# drop-in that gives it sudo without a password. The custom fact file
# /etc/ansible/facts.d/lab.fact sets the role admin on node 2 and web
# on node 3. The user appadmin, the groups appdev, appops and appaudit
# and the package zsh are gone, and /etc/motd is as it was at the first
# start.
#
# The first run records each node's package set (lib/packages.sh), and
# in /var/tmp/ansible-03.pre on each node what cleanup.sh puts back:
# on node 1 the file list of ~/.ssh, a copy of known_hosts and whether
# ~/.ansible existed; on nodes 2 and 3 a copy of /etc/motd, the lab
# groups that already existed and whether /etc/ansible existed. The
# SSH user's authorized_keys and sudoers are never touched.
# No "set -u": load-config.sh reads variables that may be unset.
set -e

source /opt/linux-labs/lib/load-config.sh
source /opt/linux-labs/lib/packages.sh
load_lab_config

LAB=ansible-03
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
if [ "$SSH_USER" = ansible ] || [ "$SSH_USER" = root ] || [ "$SSH_USER" = appadmin ]; then
	echo "$LAB needs an SSH user other than root, ansible and appadmin, SSH_USER is $SSH_USER" >&2
	exit 1
fi

NODE1_IP=$(get_node_ip 1)
NODE2_IP=$(get_node_ip 2)
NODE3_IP=$(get_node_ip 3)

for n in 1 2 3; do
	ip=$(get_node_ip "$n")
	if ! test_node_connectivity "$ip" >/dev/null; then
		echo "Cannot reach node $n ($ip) over SSH as $SSH_USER" >&2
		exit 1
	fi
done

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# fail <message>: print the message and the captured output, then exit
fail() {
	echo "$1" >&2
	grep -v "^Warning: Permanently added" "$tmp/out" >&2
	exit 1
}

# A new password for appadmin: 14 letters and digits
password=$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 14) || true
if [ "${#password}" -ne 14 ]; then
	echo "Cannot generate a password" >&2
	exit 1
fi

# Node 1 as root: records, the files of an earlier start, ansible-core.
# Runs through "bash -s -- <user>", so every command that could read
# stdin gets /dev/null.
cat > "$tmp/control.sh" <<'REMOTE'
u=$1
pre=/var/tmp/ansible-03.pre
home=$(getent passwd "$u" | cut -d: -f6)
if [ -z "$home" ] || [ ! -d "$home" ]; then
	echo "the user $u has no home directory" >&2
	exit 1
fi

if [ ! -d "$pre" ]; then
	if [ -e "$home/.ssh/ansible_lab" ] || [ -e "$home/.ssh/ansible_lab.pub" ]; then
		echo "$home/.ssh/ansible_lab exists and was not created by the lab" >&2
		exit 1
	fi
	if [ -e "$home/appadmin-password.txt" ]; then
		echo "$home/appadmin-password.txt exists and was not created by the lab" >&2
		exit 1
	fi
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
rm -f "$home/appadmin-password.txt"
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

if ! rpm -q ansible-core >/dev/null 2>&1; then
	dnf -y install ansible-core </dev/null >/dev/null 2>&1 || {
		echo "cannot install ansible-core" >&2
		exit 1
	}
fi
exit 0
REMOTE

# Node 1 as the SSH user: key pair, host keys, the project directory,
# the password file. Prints the public key.
cat > "$tmp/project.sh" <<'REMOTE'
n2=$1
n3=$2
pw=$3
umask 077
mkdir -p ~/.ssh || exit 1
ssh-keygen -q -t ed25519 -N '' -C ansible-lab -f ~/.ssh/ansible_lab </dev/null >/dev/null || exit 1
ssh-keyscan -T 10 "$n2" "$n3" </dev/null > ~/.ssh/.ansible_lab_hosts 2>/dev/null
for ip in "$n2" "$n3"; do
	if ! grep -q "^$ip " ~/.ssh/.ansible_lab_hosts; then
		echo "cannot read the SSH host keys of $ip" >&2
		rm -f ~/.ssh/.ansible_lab_hosts
		exit 1
	fi
done
cat ~/.ssh/.ansible_lab_hosts >> ~/.ssh/known_hosts || exit 1
rm -f ~/.ssh/.ansible_lab_hosts

printf 'Password of the user appadmin: %s\n' "$pw" > ~/appadmin-password.txt || exit 1

umask 022
mkdir ~/ansible-lab || exit 1
cat > ~/ansible-lab/ansible.cfg <<'EOF' || exit 1
[defaults]
inventory = ./inventory
remote_user = ansible
private_key_file = ~/.ssh/ansible_lab

[privilege_escalation]
become = true
become_method = sudo
EOF
printf '[appservers]\n%s\n%s\n' "$n2" "$n3" > ~/ansible-lab/inventory || exit 1
cat ~/.ssh/ansible_lab.pub
REMOTE

# Nodes 2 and 3 as root, with the public key and the role as arguments
cat > "$tmp/managed.sh" <<'REMOTE'
key=$1
role=$2
pre=/var/tmp/ansible-03.pre
mark="linux-labs ansible-03"
groups="appdev appops appaudit"

if [ ! -d "$pre" ]; then
	if getent passwd ansible >/dev/null &&
		[ "$(getent passwd ansible | cut -d: -f5)" != "$mark" ]; then
		echo "the user ansible already exists and was not created by the lab" >&2
		exit 1
	fi
	if getent passwd appadmin >/dev/null; then
		echo "the user appadmin already exists and was not created by the lab" >&2
		exit 1
	fi
	if [ -e /etc/ansible/facts.d/lab.fact ]; then
		echo "/etc/ansible/facts.d/lab.fact exists and was not created by the lab" >&2
		exit 1
	fi
	rm -rf "$pre.tmp"
	mkdir -m 0700 "$pre.tmp" || exit 1
	: > "$pre.tmp/flags"
	[ -e /etc/ansible ] && echo etc-ansible >> "$pre.tmp/flags"
	[ -e /etc/ansible/facts.d ] && echo facts-dir >> "$pre.tmp/flags"
	if [ -f /etc/motd ]; then
		cp -a /etc/motd "$pre.tmp/motd" || exit 1
	fi
	: > "$pre.tmp/groups"
	for g in $groups appadmin; do
		getent group "$g" >/dev/null && echo "$g" >> "$pre.tmp/groups"
	done
	mv "$pre.tmp" "$pre" || exit 1
fi

# appadmin and the groups of an earlier start
if getent passwd appadmin >/dev/null; then
	for i in 1 2 3 4 5; do
		pkill -KILL -u appadmin </dev/null >/dev/null 2>&1
		sleep 1
		userdel -r appadmin </dev/null >/dev/null 2>&1 && break
	done
	if getent passwd appadmin >/dev/null; then
		echo "cannot remove the user appadmin of an earlier start" >&2
		exit 1
	fi
fi
for g in $groups appadmin; do
	grep -qxF "$g" "$pre/groups" && continue
	getent group "$g" >/dev/null && groupdel "$g"
done

# /etc/motd as at the first start
if [ -f "$pre/motd" ]; then
	cp -a "$pre/motd" /etc/motd || exit 1
else
	rm -f /etc/motd
fi

# zsh is installed only by the playbook; pkg_restore brings back one
# that was there at the first start
if rpm -q zsh >/dev/null 2>&1; then
	dnf -y remove zsh </dev/null >/dev/null 2>&1 || {
		echo "cannot remove the package zsh" >&2
		exit 1
	}
fi

# The custom fact
mkdir -p /etc/ansible/facts.d || exit 1
printf '[server]\nrole=%s\n' "$role" > /etc/ansible/facts.d/lab.fact || exit 1
chmod 0644 /etc/ansible/facts.d/lab.fact
restorecon -R /etc/ansible >/dev/null 2>&1

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
install -d -m 0700 -o ansible -g ansible /home/ansible/.ssh || exit 1
printf '%s\n' "$key" > /home/ansible/.ssh/authorized_keys || exit 1
chown ansible:ansible /home/ansible/.ssh/authorized_keys
chmod 0600 /home/ansible/.ssh/authorized_keys
restorecon -R /home/ansible/.ssh >/dev/null 2>&1

printf 'ansible ALL=(ALL) NOPASSWD: ALL\n' > /etc/sudoers.d/.ansible-03.tmp
chmod 0440 /etc/sudoers.d/.ansible-03.tmp
if ! visudo -cqf /etc/sudoers.d/.ansible-03.tmp; then
	rm -f /etc/sudoers.d/.ansible-03.tmp
	echo "the sudoers rule for ansible does not validate" >&2
	exit 1
fi
mv /etc/sudoers.d/.ansible-03.tmp /etc/sudoers.d/ansible-03 || exit 1
restorecon /etc/sudoers.d/ansible-03 >/dev/null 2>&1
exit 0
REMOTE

for n in 1 2 3; do
	ip=$(get_node_ip "$n")
	pkg_snapshot_node "$ip" "$LAB" > "$tmp/out" 2>&1 ||
		fail "Recording the packages of node $n ($ip) failed:"
done

user_arg=$(printf '%q' "$SSH_USER")
run_on_node "$NODE1_IP" "sudo -n bash -s -- $user_arg" < "$tmp/control.sh" > "$tmp/out" 2>&1 ||
	fail "Preparing node 1 ($NODE1_IP) failed:"

run_on_node "$NODE1_IP" "bash -s -- $NODE2_IP $NODE3_IP $password" < "$tmp/project.sh" > "$tmp/key" 2> "$tmp/out" ||
	fail "Preparing the project on node 1 ($NODE1_IP) failed:"
key=$(grep '^ssh-ed25519 ' "$tmp/key" | tail -n 1)
if [ -z "$key" ]; then
	echo "Node 1 ($NODE1_IP) returned no public key" >&2
	exit 1
fi
key_arg=$(printf '%q' "$key")

run_on_node "$NODE2_IP" "sudo -n bash -s -- $key_arg admin" < "$tmp/managed.sh" > "$tmp/out" 2>&1 ||
	fail "Preparing the managed node $NODE2_IP failed:"
run_on_node "$NODE3_IP" "sudo -n bash -s -- $key_arg web" < "$tmp/managed.sh" > "$tmp/out" 2>&1 ||
	fail "Preparing the managed node $NODE3_IP failed:"

# The control node reaches both managed nodes
run_on_node "$NODE1_IP" "cd ~/ansible-lab && ANSIBLE_NOCOLOR=1 ansible all -m ansible.builtin.ping -o" \
	</dev/null > "$tmp/out" 2>&1 ||
	fail "Ansible on node 1 cannot reach nodes 2 and 3:"

# The grader checks that the lab was started and knows the password
mkdir -p "$STATE_DIR"
printf 'nodes=%s %s %s\npassword=%s\n' "$NODE1_IP" "$NODE2_IP" "$NODE3_IP" "$password" > "$STATE_FILE"
chmod 0644 "$STATE_FILE"
