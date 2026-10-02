#!/bin/bash
# ansible-01 grader
source /opt/linux-labs/lib/load-config.sh
source /opt/linux-labs/lib/grading.sh
load_lab_config

PAGE=/var/www/html/index.html
LINE="This web server is managed by Ansible."

grade_begin ansible-01
grade_require_state ansible-01

[ "$NODES_ENABLED" = "true" ] || grade_abort "Multi-node labs are enabled in the configuration"
[ "$NODE_COUNT" -ge 3 ] 2>/dev/null || grade_abort "The configuration defines at least 3 nodes"

NODE1_IP=$(get_node_ip 1)
NODE2_IP=$(get_node_ip 2)
NODE3_IP=$(get_node_ip 3)

for ip in "$NODE1_IP" "$NODE2_IP" "$NODE3_IP"; do
	test_node_connectivity "$ip" >/dev/null 2>&1 || grade_abort "Nodes 1 to 3 are reachable over SSH"
done

# on <ip> <command>: run a command as root on a node
on() {
	run_on_node "$1" "sudo -n sh -c $(printf '%q' "$2")" </dev/null 2>/dev/null
}

# ctl <command>: run a command as the SSH user on node 1 in
# ~/ansible-lab, without colours; stderr is dropped
ctl() {
	run_on_node "$NODE1_IP" "cd ~/ansible-lab 2>/dev/null || exit 99
		export LC_ALL=C.UTF-8 ANSIBLE_NOCOLOR=1 ANSIBLE_FORCE_COLOR=0
		$1" </dev/null 2>/dev/null
}

# shellcheck disable=SC2016 # expanded on node 1
PROJ=$(run_on_node "$NODE1_IP" 'printf "%s\n" "$HOME/ansible-lab"' </dev/null 2>/dev/null)
[ -n "$PROJ" ] || grade_abort "Node 1 runs commands as the SSH user"

# Settings that ansible.cfg changes, as "NAME = value" lines
CONFIG=$(ctl "ansible-config dump --only-changed" | sed -n 's/^\([A-Z_]*\)([^)]*) = /\1 = /p')

ansible_installed() {
	on "$NODE1_IP" "rpm -q ansible-core"
}

config_active() {
	ctl "test -f ansible.cfg && ansible --version" |
		grep -qxF "  config file = $PROJ/ansible.cfg"
}

inventory_set() {
	ctl "test -f inventory" || return 1
	printf '%s\n' "$CONFIG" | grep -qxF "DEFAULT_HOST_LIST = ['$PROJ/inventory']"
}

remote_user_set() {
	printf '%s\n' "$CONFIG" | grep -qxF "DEFAULT_REMOTE_USER = ansible"
}

# list_hosts <pattern>: the hosts of a pattern, sorted, one per line
list_hosts() {
	ctl "ansible $1 --list-hosts" | awk '/^ *hosts \(/ { next } NF { print $1 }' | sort
}

group_ok() {
	local want
	want=$(printf '%s\n' "$NODE2_IP" "$NODE3_IP" | sort)
	[ "$(list_hosts webservers)" = "$want" ] && [ "$(list_hosts all)" = "$want" ]
}

# key_login <ip>: the SSH user on node 1 logs in as ansible with a key
key_login() {
	run_on_node "$NODE1_IP" "ssh -o BatchMode=yes -o ConnectTimeout=10 \
		-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
		-o LogLevel=ERROR ansible@$1 true" </dev/null >/dev/null 2>&1
}

ping_ok() {
	local out
	out=$(ctl "ansible all -m ansible.builtin.ping -o") || return 1
	printf '%s\n' "$out" | grep -q "^$NODE2_IP | SUCCESS" &&
		printf '%s\n' "$out" | grep -q "^$NODE3_IP | SUCCESS"
}

syntax_ok() {
	ctl "test -f site.yml && ansible-playbook --syntax-check site.yml" >/dev/null
}

play_for_group() {
	ctl "ansible-playbook --list-hosts site.yml" | grep -q "^ *play #[0-9]* (webservers)"
}

# The playbook uses a module for the package, the file and the service
modules_ok() {
	local yml mod
	yml=$(ctl "cat site.yml") || return 1
	for mod in 'dnf|yum|package' 'copy|template' 'service|systemd|systemd_service'; do
		printf '%s\n' "$yml" |
			grep -qE "^[[:space:]]*(-[[:space:]]+)?(ansible\.builtin\.|ansible\.legacy\.)?($mod):" ||
			return 1
	done
}

# Check mode: no failures, nothing unreachable, no changes on both nodes
check_clean() {
	local out
	out=$(ctl "ansible-playbook --check site.yml") || return 1
	printf '%s\n' "$out" | awk -v a="$NODE2_IP" -v b="$NODE3_IP" '
		($1 == a || $1 == b) && $2 == ":" {
			seen[$1] = 1
			for (i = 3; i <= NF; i++) {
				if ($i ~ /^(changed|unreachable|failed)=/ && $i !~ /=0$/) bad = 1
			}
		}
		END { exit !(seen[a] && seen[b] && !bad) }'
}

httpd_installed() {
	on "$1" "rpm -q httpd"
}

page_ok() {
	local got meta
	meta=$(on "$1" "stat -c '%U:%G %a' $PAGE") || return 1
	[ "$meta" = "root:root 644" ] || return 1
	got=$(on "$1" "cat $PAGE") || return 1
	[ "$got" = "$LINE" ]
}

httpd_running() {
	on "$1" "systemctl is-enabled httpd && systemctl is-active httpd"
}

criterion "ansible-core is installed on node 1" ansible_installed
criterion "ansible.cfg in ~/ansible-lab is the active configuration" config_active
criterion "ansible.cfg sets the inventory ~/ansible-lab/inventory" inventory_set
criterion "ansible.cfg sets the remote user ansible" remote_user_set
criterion "Group webservers holds exactly $NODE2_IP and $NODE3_IP" group_ok
criterion "Key login as ansible@$NODE2_IP works from node 1" key_login "$NODE2_IP"
criterion "Key login as ansible@$NODE3_IP works from node 1" key_login "$NODE3_IP"
criterion "The ad hoc ping succeeds for both managed nodes" ping_ok
criterion "site.yml passes the syntax check" syntax_ok
criterion "site.yml has a play for the group webservers" play_for_group
criterion "site.yml uses modules for the package, file and service" modules_ok
criterion "site.yml in check mode reports no changes or failures" check_clean
for ip in "$NODE2_IP" "$NODE3_IP"; do
	criterion "httpd is installed on $ip" httpd_installed "$ip"
	criterion "index.html on $ip has the required owner, mode and line" page_ok "$ip"
	criterion "httpd is enabled and running on $ip" httpd_running "$ip"
done
grade_end
