#!/bin/bash
# ansible-02 grader
source /opt/linux-labs/lib/load-config.sh
source /opt/linux-labs/lib/grading.sh
load_lab_config

PAGE=/var/www/html/index.html
CONF=/etc/httpd/conf.d/webserver.conf
ROLE=roles/webserver
DEFAULT_GREETING="Hello from Ansible"
GROUP_GREETING="Welcome to the web farm"
HOST_GREETING="Welcome to the staging server"

grade_begin ansible-02
grade_require_state ansible-02

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

# yml_sets <file> <key> <value>: the YAML file sets key to value at the
# top level, with or without quotes
yml_sets() {
	ctl "cat $1" | grep -qxE "$2:[[:space:]]*(\"$3\"|'$3'|$3)[[:space:]]*"
}

layout_ok() {
	ctl "test -f $ROLE/tasks/main.yml && test -f $ROLE/handlers/main.yml &&
		test -f $ROLE/defaults/main.yml"
}

templates_ok() {
	ctl "test -f $ROLE/templates/index.html.j2 && test -f $ROLE/templates/webserver.conf.j2"
}

defaults_ok() {
	yml_sets "$ROLE/defaults/main.yml" web_greeting "$DEFAULT_GREETING"
}

# inventory_var <host> <value>: the inventory gives the host
# web_greeting with that value
inventory_var() {
	ctl "ansible-inventory --host $1" | grep -qF "\"web_greeting\": \"$2\""
}

group_vars_ok() {
	ctl "test -f group_vars/webservers.yml" &&
		yml_sets group_vars/webservers.yml web_greeting "$GROUP_GREETING" &&
		inventory_var "$NODE2_IP" "$GROUP_GREETING"
}

host_vars_ok() {
	ctl "test -f host_vars/$NODE3_IP.yml" &&
		yml_sets "host_vars/$NODE3_IP.yml" web_greeting "$HOST_GREETING" &&
		inventory_var "$NODE3_IP" "$HOST_GREETING"
}

# The role's tasks use template and notify a handler that restarts httpd
role_tasks_ok() {
	local yml
	yml=$(ctl "cat $ROLE/tasks/main.yml") || return 1
	printf '%s\n' "$yml" |
		grep -qE '^[[:space:]]*(-[[:space:]]+)?(ansible\.builtin\.|ansible\.legacy\.)?template:' &&
		printf '%s\n' "$yml" | grep -qE '^[[:space:]]*notify:'
}

handler_ok() {
	ctl "cat $ROLE/handlers/main.yml" |
		grep -qE "^[[:space:]]*state:[[:space:]]*[\"']?restarted[\"']?[[:space:]]*$"
}

syntax_ok() {
	ctl "test -f site.yml && ansible-playbook --syntax-check site.yml" >/dev/null
}

# A play for the group webservers that runs the tasks of the role
role_applied() {
	local out
	out=$(ctl "ansible-playbook --list-tasks site.yml") || return 1
	printf '%s\n' "$out" | grep -q "^ *play #[0-9]* (webservers)" &&
		printf '%s\n' "$out" | grep -q "^ *webserver : "
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

httpd_running() {
	on "$1" "systemctl is-enabled httpd && systemctl is-active httpd"
}

# page_ok <ip> <greeting>: index.html holds the greeting and the short
# host name of the node
page_ok() {
	local got host want
	host=$(on "$1" "uname -n") || return 1
	host=${host%%.*}
	want=$(printf '%s\nServed by %s' "$2" "$host")
	got=$(on "$1" "cat $PAGE") || return 1
	[ "$got" = "$want" ]
}

# conf_ok <ip>: webserver.conf holds the two lines for the node
conf_ok() {
	local got want
	want=$(printf '# Managed by Ansible\nServerName %s' "$1")
	got=$(on "$1" "cat $CONF") || return 1
	[ "$got" = "$want" ]
}

# A changed webserver.conf on node 2 is put back by a run of site.yml,
# and httpd gets a new main process. The original file comes back in
# any case.
handler_restarts() {
	local ip="$NODE2_IP" save=/var/tmp/ansible-02.grade before after rc=1
	before=$(on "$ip" "systemctl is-active --quiet httpd && test -f $CONF &&
		cp -a $CONF $save && echo '# changed' >> $CONF &&
		systemctl show -p MainPID httpd") || return 1
	before=${before#MainPID=}
	ctl "ansible-playbook site.yml --limit $ip" >/dev/null
	after=$(on "$ip" "systemctl show -p MainPID httpd")
	after=${after#MainPID=}
	if on "$ip" "cmp -s $CONF $save"; then
		[ -n "$after" ] && [ "$after" != 0 ] && [ "$after" != "$before" ] && rc=0
	fi
	on "$ip" "cmp -s $CONF $save || cp -a $save $CONF; rm -f $save"
	return "$rc"
}

criterion "Role webserver has tasks, handlers and defaults files" layout_ok
criterion "Role webserver has templates index.html.j2, webserver.conf.j2" templates_ok
criterion "Role defaults set web_greeting to \"$DEFAULT_GREETING\"" defaults_ok
criterion "group_vars/webservers.yml sets web_greeting for the group" group_vars_ok
criterion "host_vars/$NODE3_IP.yml sets web_greeting for node 3" host_vars_ok
criterion "Role tasks use the module template and notify a handler" role_tasks_ok
criterion "Role handlers restart a service" handler_ok
criterion "site.yml passes the syntax check" syntax_ok
criterion "site.yml applies the role webserver to the group webservers" role_applied
criterion "site.yml in check mode reports no changes or failures" check_clean
criterion "index.html on $NODE2_IP has the group greeting and host name" page_ok "$NODE2_IP" "$GROUP_GREETING"
criterion "index.html on $NODE3_IP has the host greeting and host name" page_ok "$NODE3_IP" "$HOST_GREETING"
for ip in "$NODE2_IP" "$NODE3_IP"; do
	criterion "webserver.conf on $ip has the required two lines" conf_ok "$ip"
	criterion "httpd is enabled and running on $ip" httpd_running "$ip"
done
criterion "Changing webserver.conf on node 2 triggers an httpd restart" handler_restarts
grade_end
