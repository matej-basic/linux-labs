#!/bin/bash
# users-03 setup: removes leftovers of a previous run of this lab and
# refuses to start if the accounts, IDs or directories the lab needs are
# already in use by something else. Prints nothing on success.
set -eu

STATE_DIR=/opt/linux-labs/state
STATE_FILE="$STATE_DIR/users-03"

if ! command -v setfacl >/dev/null 2>&1 || ! command -v getfacl >/dev/null 2>&1; then
	dnf -y -q install acl >/dev/null 2>&1 || {
		echo "setup: the acl package is required and could not be installed" >&2
		exit 1
	}
fi

remove_lab_objects() {
	userdel -r bob >/dev/null 2>&1 || true
	userdel -r charlie >/dev/null 2>&1 || true
	groupdel devops >/dev/null 2>&1 || true
	groupdel analytics >/dev/null 2>&1 || true
	rm -rf /srv/shared
}

if [ -e "$STATE_FILE" ]; then
	# Previous run of this lab (possibly half solved): start over
	remove_lab_objects
else
	# Fresh start: nothing may exist that the lab would destroy
	busy=""
	for u in bob charlie; do
		getent passwd "$u" >/dev/null && busy="$busy user:$u"
	done
	for g in devops analytics; do
		getent group "$g" >/dev/null && busy="$busy group:$g"
	done
	for n in 1010 1011; do
		getent passwd "$n" >/dev/null && busy="$busy uid:$n"
	done
	for n in 2000 2001; do
		getent group "$n" >/dev/null && busy="$busy gid:$n"
	done
	[ -e /srv/shared ] && busy="$busy /srv/shared"
	[ -e /home/bob ] && busy="$busy /home/bob"
	[ -e /home/charlie ] && busy="$busy /home/charlie"
	if [ -n "$busy" ]; then
		echo "setup: already in use on this system:$busy" >&2
		echo "setup: remove them first; the lab will not delete data it did not create" >&2
		exit 1
	fi
fi

mkdir -p "$STATE_DIR"
echo "users-03" > "$STATE_FILE"
chmod 644 "$STATE_FILE"
