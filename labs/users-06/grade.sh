#!/bin/bash
# users-06 grader
source /opt/linux-labs/lib/grading.sh

STATE_DIR=/opt/linux-labs/state/users-06
STATE=$STATE_DIR/state
USERS="anna ben carla dario"
PASSWORD='Harbor-Lantern-58'
NOT_BEFORE=2031-01-01

grade_begin users-06
grade_require_state users-06 "$STATE"
lab_user=$(sed -n 's/^LAB_USER=//p' "$STATE")

# config_digest: names, link targets and checksums of the PAM and login
# policy files (same function in setup.sh)
config_digest() {
	local f
	{
		find /etc/pam.d /etc/security -name 'opasswd*' -prune -o \
			\( -type f -o -type l \) -print
		echo /etc/login.defs
		echo /etc/default/useradd
	} | LC_ALL=C sort | while IFS= read -r f; do
		printf '%s %s %s\n' "$f" "$(readlink "$f")" \
			"$(sha256sum <"$f" 2>/dev/null | cut -d' ' -f1)"
	done
}

# user_digest <user>: the account, its groups, its authorized keys and
# the sudo rules (same function in setup.sh)
user_digest() {
	local home
	getent passwd "$1"
	getent shadow "$1"
	id "$1"
	home=$(getent passwd "$1" | cut -d: -f6)
	sha256sum <"$home/.ssh/authorized_keys" 2>/dev/null
	cat /etc/sudoers /etc/sudoers.d/* 2>/dev/null | sha256sum
}

# recorded <user> <field>: 2 is the UID, 3 the password hash at setup
recorded() {
	awk -F: -v u="$1" -v f="$2" '$1 == u { print $f }' "$STATE_DIR/accounts"
}

shadow_field() {
	getent shadow "$1" | cut -d: -f"$2"
}

no_faillock_records() {
	local u
	for u in $USERS; do
		faillock --user "$u" 2>/dev/null | grep -Eq '^[0-9]{4}-' && return 1
	done
	return 0
}

# A login with the password through PAM (auth and account), from an
# unprivileged account, as the student would test it. The user's shell
# expands the command.
# shellcheck disable=SC2016
LOGIN_CMD='echo "LOGIN:$PWD:$(readlink /proc/$$/exe)"'
login_works() {
	local out
	out=$(cd / && printf '%s\n' "$PASSWORD" |
		runuser -u nobody -- su - "$1" -c "$LOGIN_CMD" 2>/dev/null)
	printf '%s\n' "$out" | grep -qxF "LOGIN:/home/$1:/usr/bin/bash"
}

shells_bash() {
	local u
	for u in $USERS; do
		case "$(getent passwd "$u" | cut -d: -f7)" in
		/bin/bash | /usr/bin/bash) ;;
		*) return 1 ;;
		esac
	done
}

homes_ok() {
	local u
	for u in $USERS; do
		[ "$(getent passwd "$u" | cut -d: -f6)" = "/home/$u" ] || return 1
		[ -d "/home/$u" ] && [ ! -L "/home/$u" ] || return 1
		[ "$(stat -c %U:%a "/home/$u")" = "$u:700" ] || return 1
	done
}

skel_files() {
	local f
	[ -d /home/dario ] || return 1
	while IFS= read -r f; do
		[ -f "/home/dario/$f" ] || return 1
		[ "$(stat -c %U "/home/dario/$f")" = dario ] || return 1
	done < <(cd /etc/skel && find . -type f)
}

not_expiring() {
	local u e limit
	limit=$(($(date -u -d "$NOT_BEFORE" +%s) / 86400))
	for u in $USERS; do
		e=$(shadow_field "$u" 8)
		[ -z "$e" ] && continue
		[ "$e" -ge "$limit" ] 2>/dev/null || return 1
	done
}

not_locked() {
	local u
	for u in $USERS; do
		case "$(shadow_field "$u" 2)" in
		'' | '!'* | '*'*) return 1 ;;
		esac
	done
}

# The hash without lock marks equals the recorded one (the lock has its
# own criterion)
passwords_kept() {
	local u h
	for u in $USERS; do
		[ -n "$(recorded "$u" 3)" ] || return 1
		h=$(shadow_field "$u" 2)
		h=${h##!}
		h=${h##!}
		[ "$h" = "$(recorded "$u" 3)" ] || return 1
	done
}

uids_kept() {
	local u
	for u in $USERS; do
		[ -n "$(recorded "$u" 2)" ] || return 1
		[ "$(id -u "$u" 2>/dev/null)" = "$(recorded "$u" 2)" ] || return 1
	done
}

config_kept() {
	[ -s "$STATE_DIR/config" ] &&
		[ "$(config_digest)" = "$(cat "$STATE_DIR/config")" ]
}

lab_user_kept() {
	[ -s "$STATE_DIR/lab_user" ] &&
		[ "$(user_digest "$lab_user")" = "$(cat "$STATE_DIR/lab_user")" ]
}

# Before the logins: a successful login can reset the failure records
criterion "No faillock records for anna, ben, carla and dario" no_faillock_records
for u in $USERS; do
	criterion "$u logs in with the password into bash in /home/$u" login_works "$u"
done
criterion "The four users have the login shell /bin/bash" shells_bash
criterion "Each home /home/<user> is owned by the user, mode 0700" homes_ok
criterion "/home/dario has the files from /etc/skel, owned by dario" skel_files
criterion "No account expires before $NOT_BEFORE" not_expiring
criterion "No password of the four users is locked" not_locked
criterion "The four passwords are the ones the lab set" passwords_kept
criterion "The four users keep their UIDs" uids_kept
criterion "PAM files, /etc/security and /etc/login.defs are unchanged" config_kept
criterion "$lab_user, its keys and the sudo rules are unchanged" lab_user_kept
grade_end
