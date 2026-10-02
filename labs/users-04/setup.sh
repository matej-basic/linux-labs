#!/bin/bash
# users-04 setup: records the authselect configuration and backs up the
# PAM policy files, makes sure authselect manages PAM (profile minimal
# when no profile is selected) without the faillock and pwhistory
# features, and creates the test user pamtest. Prints nothing on success.
set -eu

LAB=users-04
STATE_DIR=/opt/linux-labs/state/$LAB
STATE=$STATE_DIR/state
BACKUP=$STATE_DIR/backup
LISTS=$STATE_DIR/lists
POLICY=/etc/security/pwquality.conf.d/50-policy.conf
TEST_USER=pamtest
TEST_PASSWORD='Quill-Harbor-472'

# Files that authselect replaces with symlinks when it selects a profile
PAM_FILES="system-auth password-auth fingerprint-auth smartcard-auth postlogin"
# Policy files the lab or the solution changes
SECURITY_FILES="pwquality.conf faillock.conf pwhistory.conf opasswd"
# Directories in which every path that appears during the lab is removed
# again by cleanup.sh
TRACKED_DIRS="/etc/authselect /var/lib/authselect /etc/dconf /etc/security /run/faillock"

fail() {
	echo "Error: $*" >&2
	exit 1
}

# A restart first undoes the previous run and its solution completely
if [ -f "$STATE" ]; then
	bash "$(dirname "$0")/cleanup.sh" >/dev/null ||
		fail "cleanup of the previous run of $LAB failed."
fi

command -v authselect >/dev/null 2>&1 || fail "authselect is not installed."
command -v faillock >/dev/null 2>&1 || fail "faillock is not installed."
command -v pwscore >/dev/null 2>&1 || fail "pwscore (libpwquality) is not installed."
if getent passwd "$TEST_USER" >/dev/null; then
	fail "user $TEST_USER already exists and was not created by this lab."
fi
[ -e "$POLICY" ] && fail "$POLICY already exists."

baseline=$(authselect current --raw 2>/dev/null) || baseline=""
if [ -n "$baseline" ] && ! authselect check >/dev/null 2>&1; then
	fail "the PAM files do not match the authselect configuration (authselect check)."
fi

rm -rf "$STATE_DIR"
mkdir -p "$BACKUP/pam.d" "$BACKUP/security" "$LISTS"
chmod 0755 "$STATE_DIR"
chmod 0700 "$BACKUP"

# Backups (symlinks stay symlinks) and the content of the directories
for f in $PAM_FILES; do
	if [ -e "/etc/pam.d/$f" ] || [ -L "/etc/pam.d/$f" ]; then
		cp -a "/etc/pam.d/$f" "$BACKUP/pam.d/$f"
	fi
done
cp -a /etc/nsswitch.conf "$BACKUP/nsswitch.conf"
for f in $SECURITY_FILES; do
	if [ -e "/etc/security/$f" ]; then
		cp -a "/etc/security/$f" "$BACKUP/security/$f"
	fi
done
for d in $TRACKED_DIRS; do
	name=$(echo "$d" | tr / _)
	if [ -e "$d" ]; then
		find "$d" -print > "$LISTS/$name"
	else
		: > "$LISTS/$name"
	fi
done
# From here on cleanup.sh can undo everything, also after a failure
{
	echo "BASELINE=$baseline"
	echo "LAB_USER=${LAB_USER:-student}"
} > "$STATE"
chmod 0644 "$STATE"

# Starting point: a profile without the two features of the task
if [ -z "$baseline" ]; then
	authselect select minimal --force >/dev/null 2>&1 ||
		fail "authselect cannot select the profile minimal."
else
	for feature in with-faillock with-pwhistory; do
		case " $baseline " in
		*" $feature "*)
			authselect disable-feature "$feature" >/dev/null 2>&1 ||
				fail "authselect cannot disable $feature."
			;;
		esac
	done
fi
lab_config=$(authselect current --raw 2>/dev/null) ||
	fail "authselect has no configuration after setup."

# The test user for the lockout and password checks
useradd -m -s /bin/bash "$TEST_USER" >/dev/null 2>&1 ||
	fail "cannot create user $TEST_USER."
echo "$TEST_USER:$TEST_PASSWORD" | chpasswd >/dev/null 2>&1 ||
	fail "cannot set the password of $TEST_USER."
faillock --user "$TEST_USER" --reset >/dev/null 2>&1 || true
getent shadow "$TEST_USER" | cut -d: -f2 > "$STATE_DIR/hash"
chmod 0600 "$STATE_DIR/hash"

echo "LAB_CONFIG=$lab_config" >> "$STATE"

exit 0
