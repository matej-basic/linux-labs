#!/bin/bash
# ansible-02 cleanup: puts nodes 1 to 3 back into the state that the
# first setup.sh run recorded.
#
# Node 1: the SSH connections Ansible keeps open end, ~/ansible-lab
# goes, ~/.ansible goes unless it existed before, files in ~/.ssh that
# were not there before go (authorized_keys is never touched) and
# known_hosts comes back as recorded. Then the package set of the first
# start comes back (lib/packages.sh), which removes ansible-core again.
# Nodes 2 and 3: httpd stops, index.html, webserver.conf, the user
# ansible and its sudoers drop-in go, then the package set comes back,
# which removes httpd and its system user. Where httpd was there
# before, its page, webserver.conf and service state come back as
# recorded.
# When a node cannot be restored, its records stay for the next reset
# and the exit status is 1.
# No "set -u": load-config.sh reads variables that may be unset.

source /opt/linux-labs/lib/load-config.sh
source /opt/linux-labs/lib/packages.sh
load_lab_config

LAB=ansible-02
STATE_FILE="/opt/linux-labs/state/$LAB"

# Nothing was started without multi-node support
if [ "$NODES_ENABLED" != "true" ] || ! [ "$NODE_COUNT" -ge 3 ] 2>/dev/null; then
	rm -f "$STATE_FILE"
	exit 0
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Node 1 before the package restore
cat > "$tmp/control.sh" <<'REMOTE'
u=$1
pre=/var/tmp/ansible-02.pre
[ -d "$pre" ] || exit 0
home=$(getent passwd "$u" | cut -d: -f6)
[ -n "$home" ] && [ -d "$home" ] || exit 0

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

# Node 1 after the package restore: what ansible-core leaves behind
cat > "$tmp/control-post.sh" <<'REMOTE'
pre=/var/tmp/ansible-02.pre
[ -d "$pre" ] || exit 0
for d in /etc/ansible /usr/share/ansible; do
	if [ -d "$d" ] && ! rpm -qf "$d" >/dev/null 2>&1; then
		rm -rf --one-file-system "$d"
	fi
done
rm -rf "$pre"
exit 0
REMOTE

# Nodes 2 and 3 before the package restore
cat > "$tmp/managed.sh" <<'REMOTE'
mark="linux-labs ansible-02"

if systemctl cat httpd </dev/null >/dev/null 2>&1; then
	systemctl disable --now httpd </dev/null >/dev/null 2>&1
fi
if [ -d /var/tmp/ansible-02.pre ]; then
	rm -f /var/www/html/index.html /etc/httpd/conf.d/webserver.conf
fi

if getent passwd ansible >/dev/null &&
	[ "$(getent passwd ansible | cut -d: -f5)" = "$mark" ]; then
	for i in 1 2 3 4 5; do
		pkill -KILL -u ansible </dev/null >/dev/null 2>&1
		sleep 1
		userdel -r ansible </dev/null >/dev/null 2>&1 && break
	done
	if getent passwd ansible >/dev/null; then
		echo "cannot remove the user ansible" >&2
		exit 1
	fi
fi
rm -f /etc/sudoers.d/ansible-02 /etc/sudoers.d/.ansible-02.tmp \
	/var/tmp/ansible-02.grade
exit 0
REMOTE

# Nodes 2 and 3 after the package restore: httpd as recorded, or its
# leftovers gone where the lab installed it
cat > "$tmp/managed-post.sh" <<'REMOTE'
pre=/var/tmp/ansible-02.pre
[ -d "$pre" ] || exit 0

had() {
	grep -qx "$1" "$pre/flags" 2>/dev/null
}

if rpm -q httpd >/dev/null 2>&1; then
	if [ -f "$pre/index.html" ]; then
		cp -a "$pre/index.html" /var/www/html/index.html
	fi
	if [ -f "$pre/webserver.conf" ]; then
		cp -a "$pre/webserver.conf" /etc/httpd/conf.d/webserver.conf
	fi
	had httpd-enabled && systemctl enable httpd </dev/null >/dev/null 2>&1
	had httpd-active && systemctl start httpd </dev/null >/dev/null 2>&1
else
	for d in /etc/httpd /var/www /var/log/httpd; do
		if [ -d "$d" ] && ! rpm -qf "$d" >/dev/null 2>&1; then
			rm -rf --one-file-system "$d"
		fi
	done
fi
rm -rf "$pre"
exit 0
REMOTE

user_arg=$(printf '%q' "$SSH_USER")
rc=0
for n in 1 2 3; do
	ip=$(get_node_ip "$n")
	if [ "$n" = 1 ]; then
		stop="$tmp/control.sh"
		post="$tmp/control-post.sh"
	else
		stop="$tmp/managed.sh"
		post="$tmp/managed-post.sh"
	fi
	if ! run_on_node "$ip" "sudo -n bash -s -- $user_arg" < "$stop" > "$tmp/out" 2>&1; then
		echo "Cleanup of node $n ($ip) failed:" >&2
		grep -v "^Warning: Permanently added" "$tmp/out" >&2
		rc=1
		continue
	fi
	pkg_restore_node "$ip" "$LAB" 2>"$tmp/err" || {
		echo "Restoring the packages of node $n ($ip) failed:" >&2
		grep -v "^Warning: Permanently added" "$tmp/err" >&2
		# Keep the records of this node for the next reset
		rc=1
		continue
	}
	if ! run_on_node "$ip" "sudo -n bash -s" < "$post" > "$tmp/out" 2>&1; then
		echo "Cleanup of node $n ($ip) failed:" >&2
		grep -v "^Warning: Permanently added" "$tmp/out" >&2
		rc=1
	fi
done

[ "$rc" -eq 0 ] && rm -f "$STATE_FILE"
exit "$rc"
