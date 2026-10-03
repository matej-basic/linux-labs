#!/bin/bash
# users-06 setup: creates anna, ben, carla and dario with the same
# password and breaks each account in a different way. Records the
# password hashes, the UIDs, a digest of the PAM and login policy files
# and of the task user. Prints nothing on success.
#
#   anna   account expired
#   ben    password locked
#   carla  login shell /sbin/nologin
#   dario  home directory missing
set -eu

LAB=users-06
STATE_DIR=/opt/linux-labs/state/$LAB
STATE=$STATE_DIR/state
USERS="anna ben carla dario"
PASSWORD='Harbor-Lantern-58'
EXPIRED=2024-06-30

fail() {
	echo "Error: $*" >&2
	exit 1
}

# config_digest: names, link targets and checksums of the PAM and login
# policy files (same function in grade.sh)
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
# the sudo rules (same function in grade.sh)
user_digest() {
	local home
	getent passwd "$1"
	getent shadow "$1"
	id "$1"
	home=$(getent passwd "$1" | cut -d: -f6)
	sha256sum <"$home/.ssh/authorized_keys" 2>/dev/null
	cat /etc/sudoers /etc/sudoers.d/* 2>/dev/null | sha256sum
}

# A restart first undoes the previous run and its solution completely
if [ -d "$STATE_DIR" ]; then
	bash "$(dirname "$0")/cleanup.sh" >/dev/null ||
		fail "cleanup of the previous run of $LAB failed."
fi

lab_user="${LAB_USER:-student}"
if ! id "$lab_user" >/dev/null 2>&1; then
	lab_user=$(getent passwd | awk -F: '$3 >= 1000 && $3 < 60000 { print $1; exit }')
	lab_user="${lab_user:-root}"
fi

command -v faillock >/dev/null 2>&1 || fail "faillock is not installed."
for u in $USERS; do
	getent passwd "$u" >/dev/null &&
		fail "user $u already exists and was not created by this lab."
	getent group "$u" >/dev/null &&
		fail "group $u already exists and was not created by this lab."
	[ -e "/home/$u" ] && fail "/home/$u already exists."
	[ -e "/var/spool/mail/$u" ] && fail "/var/spool/mail/$u already exists."
done

mkdir -p "$STATE_DIR"
chmod 0755 "$STATE_DIR"
# From here on cleanup.sh removes the users, also after a failure
echo "LAB_USER=$lab_user" >"$STATE"
chmod 0644 "$STATE"

for u in $USERS; do
	if [ "$u" = dario ]; then
		useradd -M -d "/home/$u" -s /bin/bash "$u" ||
			fail "cannot create user $u."
	else
		useradd -m -s /bin/bash "$u" || fail "cannot create user $u."
	fi
	echo "$u:$PASSWORD" | chpasswd || fail "cannot set the password of $u."
	faillock --user "$u" --reset >/dev/null 2>&1 || true
done

: >"$STATE_DIR/accounts"
chmod 0600 "$STATE_DIR/accounts"
for u in $USERS; do
	printf '%s:%s:%s\n' "$u" "$(id -u "$u")" \
		"$(getent shadow "$u" | cut -d: -f2)" >>"$STATE_DIR/accounts"
done

# The faults
chage -E "$EXPIRED" anna || fail "cannot set the expiry date of anna."
usermod -L ben || fail "cannot lock the password of ben."
usermod -s /sbin/nologin carla || fail "cannot change the shell of carla."

config_digest >"$STATE_DIR/config"
chmod 0600 "$STATE_DIR/config"
user_digest "$lab_user" >"$STATE_DIR/lab_user"
chmod 0600 "$STATE_DIR/lab_user"

exit 0
