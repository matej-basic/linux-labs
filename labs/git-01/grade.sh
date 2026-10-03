#!/bin/bash
# git-01 grader
source /opt/linux-labs/lib/load-config.sh
source /opt/linux-labs/lib/grading.sh
load_lab_config

LAB=git-01
STATE_FILE=/opt/linux-labs/state/$LAB
REPO=/srv/git/project.git
FIRST_LINE="Shared project repository"
AUTHOR="Lab Admin <admin@lab.example>"

grade_begin git-01
grade_require_state git-01 "$STATE_FILE"

[ "$NODES_ENABLED" = "true" ] || grade_abort "Multi-node labs are enabled in the configuration"
[ "$NODE_COUNT" -ge 2 ] 2>/dev/null || grade_abort "The configuration defines at least 2 nodes"

N1=$(get_node_ip 1)
N2=$(get_node_ip 2)
for ip in "$N1" "$N2"; do
	test_node_connectivity "$ip" >/dev/null 2>&1 || grade_abort "Nodes 1 and 2 are reachable over SSH"
done

# The public key of the node account on node 2 (type and key data)
pub=$(run_on_node "$N2" "cat ~/.ssh/id_ed25519.pub" </dev/null 2>/dev/null |
	awk 'NF >= 2 { print $1, $2; exit }')

# Node 1, as root: one line "<check> <0|1>" per check, and the commit
# of main in the bare repository as "main <hash>"
node1_checks() {
	cat <<'REMOTE'
r() {
	if "$@" >/dev/null 2>&1; then echo 0; else echo 1; fi
}
# g <git arguments>: git as the user git on the bare repository
g() {
	(cd / && runuser -u git -- env HOME=/home/git git --git-dir="$REPO" "$@") 2>/dev/null
}
ent=$(getent passwd git)
home=$(printf '%s' "$ent" | cut -d: -f6)
shell=$(printf '%s' "$ent" | cut -d: -f7)

user_ok() {
	[ -n "$ent" ] && [ "$home" = /home/git ] &&
		[ "${shell##*/}" = git-shell ] && [ -x "$shell" ]
}
shells_ok() {
	[ -n "$shell" ] && grep -qxF "$shell" /etc/shells
}
bare_ok() {
	[ -d "$REPO" ] && [ -n "$ent" ] &&
		[ "$(stat -c %U "$REPO")" = git ] &&
		[ -z "$(find "$REPO" ! -user git -print -quit)" ] &&
		[ "$(g rev-parse --is-bare-repository)" = true ]
}
head_ok() {
	[ -n "$ent" ] && [ "$(g symbolic-ref HEAD)" = refs/heads/main ]
}
modes_ok() {
	local d=/home/git/.ssh
	[ -n "$ent" ] && [ -d "$d" ] && [ -f "$d/authorized_keys" ] &&
		[ "$(stat -c '%a %U' "$d")" = "700 git" ] &&
		[ "$(stat -c '%a %U' "$d/authorized_keys")" = "600 git" ]
}
key_ok() {
	[ -n "$PUB" ] && [ -f /home/git/.ssh/authorized_keys ] &&
		grep -qF -- "$PUB" /home/git/.ssh/authorized_keys
}
readme_ok() {
	[ -n "$ent" ] &&
		[ "$(g show main:README.md | head -n 1)" = "$FIRST_LINE" ]
}
author_ok() {
	[ -n "$ent" ] &&
		[ "$(g log -1 --format='%an <%ae>' main)" = "$AUTHOR" ]
}

echo "git $(r rpm -q git)"
echo "user $(r user_ok)"
echo "shells $(r shells_ok)"
echo "bare $(r bare_ok)"
echo "head $(r head_ok)"
echo "modes $(r modes_ok)"
echo "key $(r key_ok)"
echo "readme $(r readme_ok)"
echo "author $(r author_ok)"
[ -n "$ent" ] && echo "main $(g rev-parse --verify -q refs/heads/main)"
exit 0
REMOTE
}

# Node 2, as the node account: the same format. The SSH checks use the
# lab key and leave known_hosts alone.
node2_checks() {
	cat <<'REMOTE'
r() {
	if "$@" >/dev/null 2>&1; then echo 0; else echo 1; fi
}
SSH="ssh -i $HOME/.ssh/id_ed25519 -o IdentitiesOnly=yes -o BatchMode=yes"
SSH="$SSH -o ConnectTimeout=10 -o StrictHostKeyChecking=no"
SSH="$SSH -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"
P=$HOME/project
pg() {
	git -C "$P" "$@" 2>/dev/null
}

access_ok() {
	GIT_SSH_COMMAND="$SSH" timeout 30 git ls-remote "git@$N1:$REPO" </dev/null
}
refused() {
	local out
	access_ok || return 1
	# A shell prints git01-42; git-shell only repeats the command in
	# its error message
	out=$(timeout 30 $SSH "git@$N1" 'echo git01-$((6 * 7))' </dev/null 2>&1)
	! printf '%s\n' "$out" | grep -q git01-42
}
clone_ok() {
	local url
	[ "$(pg rev-parse --show-toplevel)" = "$P" ] || return 1
	url=$(pg config --get remote.origin.url)
	[ "$url" = "git@$N1:$REPO" ] || [ "$url" = "ssh://git@$N1$REPO" ] ||
		[ "$url" = "ssh://git@$N1:22$REPO" ]
}
identity_ok() {
	[ "$(pg config --local --get user.name)" = "Lab Admin" ] &&
		[ "$(pg config --local --get user.email)" = admin@lab.example ]
}
tracks_ok() {
	[ "$(pg rev-parse --abbrev-ref 'main@{upstream}')" = origin/main ] &&
		[ -n "$MAIN" ] && [ "$(pg rev-parse --verify -q refs/heads/main)" = "$MAIN" ]
}

echo "git $(r rpm -q git)"
echo "access $(r access_ok)"
echo "refused $(r refused)"
echo "clone $(r clone_ok)"
echo "identity $(r identity_ok)"
echo "tracks $(r tracks_ok)"
exit 0
REMOTE
}

n1=$({
	printf "REPO='%s'; FIRST_LINE='%s'; AUTHOR='%s'; PUB='%s'\n" \
		"$REPO" "$FIRST_LINE" "$AUTHOR" "$pub"
	node1_checks
} | run_on_node "$N1" "sudo -n bash -s" 2>/dev/null)
main=$(printf '%s\n' "$n1" | awk '$1 == "main" { print $2; exit }')

n2=$({
	printf "N1='%s'; REPO='%s'; MAIN='%s'\n" "$N1" "$REPO" "$main"
	node2_checks
} | run_on_node "$N2" "bash -s" 2>/dev/null)

# res <output> <check>: the result of a check, 1 when it is missing
res() {
	local v
	v=$(printf '%s\n' "$1" | awk -v k="$2" '$1 == k { print $2; exit }')
	echo "${v:-1}"
}

criterion_result "git is installed on node 1" "$(res "$n1" git)"
criterion_result "git is installed on node 2" "$(res "$n2" git)"
criterion_result "User git on node 1 has home /home/git and shell git-shell" "$(res "$n1" user)"
criterion_result "/etc/shells on node 1 lists the login shell of git" "$(res "$n1" shells)"
criterion_result "$REPO is a bare repository owned by git" "$(res "$n1" bare)"
criterion_result "HEAD of the bare repository names the branch main" "$(res "$n1" head)"
criterion_result "/home/git/.ssh has mode 0700, authorized_keys 0600, owner git" "$(res "$n1" modes)"
criterion_result "/home/git/.ssh/authorized_keys holds the node 2 key" "$(res "$n1" key)"
criterion_result "The node 2 key reaches the repository over SSH as git" "$(res "$n2" access)"
criterion_result "SSH as git refuses commands other than Git commands" "$(res "$n2" refused)"
criterion_result "Branch main has README.md with the required first line" "$(res "$n1" readme)"
criterion_result "The latest commit on main is by $AUTHOR" "$(res "$n1" author)"
criterion_result "The node 2 clone ~/project has the node 1 repository as origin" "$(res "$n2" clone)"
criterion_result "The clone ~/project sets user.name and user.email as required" "$(res "$n2" identity)"
criterion_result "main in ~/project tracks origin/main and is pushed" "$(res "$n2" tracks)"
grade_end
