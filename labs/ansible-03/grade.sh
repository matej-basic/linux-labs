#!/bin/bash
# ansible-03 grader
source /opt/linux-labs/lib/load-config.sh
source /opt/linux-labs/lib/grading.sh
load_lab_config

STATE_FILE=/opt/linux-labs/state/ansible-03
VAULT=group_vars/appservers/vault.yml
GROUPS_JSON='"app_groups":["appdev","appops","appaudit"]'

grade_begin ansible-03
grade_require_state ansible-03 "$STATE_FILE"

[ "$NODES_ENABLED" = "true" ] || grade_abort "Multi-node labs are enabled in the configuration"
[ "$NODE_COUNT" -ge 3 ] 2>/dev/null || grade_abort "The configuration defines at least 3 nodes"

PW=$(sed -n 's/^password=//p' "$STATE_FILE")
[ -n "$PW" ] || grade_abort "Lab was started with labctl start"

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

vault_encrypted() {
	# shellcheck disable=SC2016 # the literal vault header
	[ "$(ctl "head -n 1 $VAULT")" = '$ANSIBLE_VAULT;1.1;AES256' ]
}

# The password is not in vault.yml as plain text, and vault.yml
# decrypts to a file that sets appadmin_password to it
vault_holds_secret() {
	ctl "test -f $VAULT && ! grep -qF -- '$PW' $VAULT" || return 1
	ctl "ansible-vault view $VAULT" |
		grep -qxE "appadmin_password:[[:space:]]*(\"$PW\"|'$PW'|$PW)[[:space:]]*"
}

# ansible.cfg names ~/ansible-lab/.vault_pass as the vault password file
vault_cfg() {
	# shellcheck disable=SC2016 # expands on node 1
	ctl 'v=$(ansible-config dump --only-changed |
			sed -n "s/^DEFAULT_VAULT_PASSWORD_FILE([^)]*) = //p")
		[ -n "$v" ] && grep -q "^[[:space:]]*vault_password_file[[:space:]]*=" ansible.cfg &&
		[ "$(realpath -e "$v")" = "$(realpath -e .vault_pass)" ]'
}

vault_pass_mode() {
	[ "$(ctl "stat -c %a .vault_pass")" = 600 ]
}

# No plain file of the project holds the password, apart from the
# vault password file
no_plain_secret() {
	ctl "test -f users.yml" || return 1
	ctl "! grep -rqF --exclude=.vault_pass -- '$PW' ."
}

groups_var() {
	ctl "test -f group_vars/appservers/vars.yml" &&
		ctl "ansible-inventory --host $NODE2_IP" | tr -d ' \t\n' | grep -qF "$GROUPS_JSON"
}

syntax_ok() {
	ctl "test -f users.yml && ansible-playbook --syntax-check users.yml" >/dev/null
}

uses_loop_when() {
	local yml
	yml=$(ctl "cat users.yml") || return 1
	printf '%s\n' "$yml" | grep -qE '^[[:space:]]*(loop|with_items|with_list):' &&
		printf '%s\n' "$yml" | grep -qE '^[[:space:]]*when:' &&
		printf '%s\n' "$yml" | grep -qF ansible_local
}

template_ok() {
	ctl "test -f templates/motd.j2"
}

# Check mode: no failures, nothing unreachable, no changes on both nodes
check_clean() {
	local out
	out=$(ctl "ansible-playbook --check users.yml") || return 1
	printf '%s\n' "$out" | awk -v a="$NODE2_IP" -v b="$NODE3_IP" '
		($1 == a || $1 == b) && $2 == ":" {
			seen[$1] = 1
			for (i = 3; i <= NF; i++) {
				if ($i ~ /^(changed|unreachable|failed)=/ && $i !~ /=0$/) bad = 1
			}
		}
		END { exit !(seen[a] && seen[b] && !bad) }'
}

# appadmin has a SHA-512 hash in /etc/shadow that matches the password.
# platform-python on Rocky Linux 8, python3 on Rocky Linux 9.
password_ok() {
	on "$1" "h=\$(getent shadow appadmin | cut -d: -f2)
		case \$h in '\$6\$'*) ;; *) exit 1 ;; esac
		py=/usr/libexec/platform-python
		[ -x \$py ] || py=python3
		H=\$h P='$PW' \$py -c 'import crypt, os, sys
sys.exit(crypt.crypt(os.environ[\"P\"], os.environ[\"H\"]) != os.environ[\"H\"])'"
}

groups_ok() {
	on "$1" "getent group appdev && getent group appops && getent group appaudit"
}

member_ok() {
	local g
	g=" $(on "$1" "id -nG appadmin") " || return 1
	case $g in *" appdev "*) ;; *) return 1 ;; esac
	case $g in *" appops "*) ;; *) return 1 ;; esac
	case $g in *" appaudit "*) ;; *) return 1 ;; esac
}

# motd_ok <ip>: /etc/motd holds the two lines with the major release and
# the memory in MB that Ansible gathers as facts
motd_ok() {
	local want got
	want=$(on "$1" ". /etc/os-release
		m=\$(awk '/^MemTotal:/ { print int(\$2 / 1024) }' /proc/meminfo)
		printf 'Managed by Ansible\nRelease %s with %s MB of memory\n' \"\${VERSION_ID%%.*}\" \"\$m\"") || return 1
	got=$(on "$1" "cat /etc/motd") || return 1
	[ -n "$want" ] && [ "$got" = "$want" ]
}

zsh_conditional() {
	on "$NODE2_IP" "rpm -q zsh" && ! on "$NODE3_IP" "rpm -q zsh"
}

criterion "vault.yml is encrypted with ansible-vault (AES256)" vault_encrypted
criterion "vault.yml sets appadmin_password and hides it" vault_holds_secret
criterion "ansible.cfg names .vault_pass as the vault password file" vault_cfg
criterion "The vault password file has mode 0600" vault_pass_mode
criterion "No plain project file holds the appadmin password" no_plain_secret
criterion "group_vars/appservers/vars.yml sets the list app_groups" groups_var
criterion "users.yml passes the syntax check" syntax_ok
criterion "users.yml uses a loop and a condition on ansible_local" uses_loop_when
criterion "Template templates/motd.j2 exists" template_ok
criterion "users.yml in check mode reports no changes or failures" check_clean
for ip in "$NODE2_IP" "$NODE3_IP"; do
	criterion "appadmin on $ip has the password from the vault" password_ok "$ip"
	criterion "Groups appdev, appops and appaudit exist on $ip" groups_ok "$ip"
	criterion "appadmin on $ip is a member of the three groups" member_ok "$ip"
	criterion "/etc/motd on $ip has the release and memory from facts" motd_ok "$ip"
done
criterion "zsh is installed on node 2 only" zsh_conditional
grade_end
