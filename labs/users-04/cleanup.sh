#!/bin/bash
# users-04 cleanup: removes pamtest, puts the authselect configuration
# back to what setup recorded, restores the PAM policy files from the
# backups and removes every file that appeared during the lab in the
# directories setup listed.
LAB=users-04
STATE_DIR=/opt/linux-labs/state/$LAB
STATE=$STATE_DIR/state
BACKUP=$STATE_DIR/backup
LISTS=$STATE_DIR/lists
TEST_USER=pamtest

PAM_FILES="system-auth password-auth fingerprint-auth smartcard-auth postlogin"
SECURITY_FILES="pwquality.conf faillock.conf pwhistory.conf opasswd"
TRACKED_DIRS="/etc/authselect /var/lib/authselect /etc/dconf /etc/security /run/faillock"

rc=0

# Without the state file the lab did not start: leave the system alone
if [ ! -f "$STATE" ]; then
	rm -rf "$STATE_DIR"
	exit 0
fi

baseline=$(sed -n 's/^BASELINE=//p' "$STATE")

# The test user and its failure records
faillock --user "$TEST_USER" --reset >/dev/null 2>&1
if getent passwd "$TEST_USER" >/dev/null; then
	userdel -r -f "$TEST_USER" >/dev/null 2>&1
fi
rm -f "/var/run/faillock/$TEST_USER"

# has_word <list> <word>
has_word() {
	case " $1 " in
	*" $2 "*) return 0 ;;
	esac
	return 1
}

# authselect configuration
if [ -z "$baseline" ]; then
	# No profile before the lab: put the original files back in place of
	# the authselect symlinks
	for f in $PAM_FILES; do
		if [ -e "$BACKUP/pam.d/$f" ] || [ -L "$BACKUP/pam.d/$f" ]; then
			rm -f "/etc/pam.d/$f"
			cp -a "$BACKUP/pam.d/$f" "/etc/pam.d/$f" || rc=1
		fi
	done
	if [ -e "$BACKUP/nsswitch.conf" ] || [ -L "$BACKUP/nsswitch.conf" ]; then
		rm -f /etc/nsswitch.conf
		cp -a "$BACKUP/nsswitch.conf" /etc/nsswitch.conf || rc=1
	fi
else
	current=$(authselect current --raw 2>/dev/null)
	if [ "${current%% *}" = "${baseline%% *}" ]; then
		# Same profile: switch only the features that differ
		for feature in ${current#* }; do
			[ "$feature" = "${current%% *}" ] && continue
			has_word "$baseline" "$feature" ||
				authselect disable-feature "$feature" >/dev/null 2>&1
		done
		for feature in ${baseline#* }; do
			[ "$feature" = "${baseline%% *}" ] && continue
			has_word "$current" "$feature" ||
				authselect enable-feature "$feature" >/dev/null 2>&1
		done
	fi
	if [ "$(authselect current --raw 2>/dev/null)" != "$baseline" ]; then
		# shellcheck disable=SC2086 # profile and features are words
		authselect select $baseline --force >/dev/null 2>&1 || rc=1
	elif ! authselect check >/dev/null 2>&1; then
		# The PAM files were edited by hand: generate them again
		authselect apply-changes >/dev/null 2>&1 || rc=1
	fi
fi

# PAM policy files
for f in $SECURITY_FILES; do
	if [ -e "$BACKUP/security/$f" ]; then
		cp -a "$BACKUP/security/$f" "/etc/security/$f" || rc=1
	fi
done

# Remove what appeared in the tracked directories during the lab, such
# as the pwquality.conf.d file, opasswd.old and authselect backups
for d in $TRACKED_DIRS; do
	list="$LISTS/$(echo "$d" | tr / _)"
	[ -f "$list" ] || continue
	[ -e "$d" ] || continue
	find "$d" -depth -print | while IFS= read -r p; do
		grep -qxF -- "$p" "$list" || rm -rf -- "$p"
	done
done

restorecon -RF /etc/pam.d /etc/nsswitch.conf /etc/authselect /etc/security >/dev/null 2>&1

if [ -n "$baseline" ] && [ "$(authselect current --raw 2>/dev/null)" != "$baseline" ]; then
	echo "Error: authselect is not back to: $baseline" >&2
	rc=1
fi

# Keep the backups when something failed, so that a second reset can
# try again
[ "$rc" -eq 0 ] && rm -rf "$STATE_DIR"
exit "$rc"
