#!/bin/bash
# users-04 grader
source /opt/linux-labs/lib/grading.sh

STATE_DIR=/opt/linux-labs/state/users-04
STATE=$STATE_DIR/state
POLICY=/etc/security/pwquality.conf.d/50-policy.conf
FAILLOCK=/etc/security/faillock.conf
PWHISTORY=/etc/security/pwhistory.conf
OPASSWD=/etc/security/opasswd
TEST_USER=pamtest
TEST_PASSWORD='Quill-Harbor-472'
# Passwords for the passwd checks: 11 characters, two character classes,
# a password that meets the policy
SHORT_PASSWORD='Vt9-plum-Or'
TWO_CLASS_PASSWORD='vtplumorbitkx42'
GOOD_PASSWORD='Vt9-plum-Orbit-x'

grade_begin users-04
grade_require_state users-04 "$STATE"
lab_config=$(sed -n 's/^LAB_CONFIG=//p' "$STATE")
profile=${lab_config%% *}
current=$(authselect current --raw 2>/dev/null)

profile_kept() {
	[ -n "$profile" ] && [ "${current%% *}" = "$profile" ]
}

feature_enabled() {
	case " $current " in
	*" $1 "*) return 0 ;;
	esac
	return 1
}

# conf_value <file> <key>: last active value of "key = value" in a file
conf_value() {
	[ -f "$1" ] || return 0
	awk -v k="$2" '
		{ sub(/#.*/, "") }
		{
			n = index($0, "=")
			if (n == 0) next
			key = substr($0, 1, n - 1); val = substr($0, n + 1)
			gsub(/[[:space:]]/, "", key); gsub(/^[[:space:]]+|[[:space:]]+$/, "", val)
			if (key == k) v = val
		}
		END { print v }' "$1"
}

# conf_flag <file> <key>: the file has the key as an active line
conf_flag() {
	[ -f "$1" ] && grep -Eq "^[[:space:]]*$2[[:space:]]*$" "$1"
}

# pwquality_value <key>: the effective value; libpwquality reads the
# pwquality.conf.d files in sorted order and pwquality.conf last
pwquality_value() {
	local LC_ALL=C f v val=""
	for f in /etc/security/pwquality.conf.d/*.conf /etc/security/pwquality.conf; do
		v=$(conf_value "$f" "$1")
		[ -n "$v" ] && val=$v
	done
	echo "$val"
}

# pwquality_is <key> <value>: set in the policy file and in effect
pwquality_is() {
	[ "$(conf_value "$POLICY" "$1")" = "$2" ] &&
		[ "$(pwquality_value "$1")" = "$2" ]
}

# The PAM checks below change pamtest and its records; they start from
# the state that setup created and put everything back afterwards.
su_as_test_user() {
	echo "$1" | runuser -u nobody -- su "$TEST_USER" -c true >/dev/null 2>&1
}

set_password() {
	echo "$1" | passwd --stdin "$TEST_USER" >/dev/null 2>&1
}

lock_rc=1
short_rc=1
classes_rc=1
good_rc=1
history_rc=1
if getent passwd "$TEST_USER" >/dev/null && [ -s "$STATE_DIR/hash" ]; then
	hash=$(cat "$STATE_DIR/hash")
	work=$(mktemp -d)
	opasswd_old=0
	[ -e "$OPASSWD.old" ] && opasswd_old=1
	[ -e "$OPASSWD" ] && cp -p "$OPASSWD" "$work/opasswd"
	usermod -p "$hash" "$TEST_USER" >/dev/null 2>&1
	faillock --user "$TEST_USER" --reset >/dev/null 2>&1
	# Forget earlier passwords of pamtest, for example from practice
	[ -e "$OPASSWD" ] && sed -i "/^$TEST_USER:/d" "$OPASSWD"

	# Lockout: the password works, three failures lock the account
	if su_as_test_user "$TEST_PASSWORD"; then
		for _ in 1 2 3; do
			su_as_test_user wrong-password
		done
		if faillock --user "$TEST_USER" | grep -q " V$" &&
			! su_as_test_user "$TEST_PASSWORD"; then
			lock_rc=0
		fi
	fi
	faillock --user "$TEST_USER" --reset >/dev/null 2>&1

	# Password quality and history, as root
	set_password "$SHORT_PASSWORD" || short_rc=0
	set_password "$TWO_CLASS_PASSWORD" || classes_rc=0
	if set_password "$GOOD_PASSWORD"; then
		good_rc=0
		set_password "$TEST_PASSWORD" || history_rc=0
	fi

	# Put pamtest and opasswd back
	usermod -p "$hash" "$TEST_USER" >/dev/null 2>&1
	faillock --user "$TEST_USER" --reset >/dev/null 2>&1
	if [ -e "$work/opasswd" ]; then
		cp -p "$work/opasswd" "$OPASSWD"
	fi
	[ "$opasswd_old" -eq 0 ] && rm -f "$OPASSWD.old"
	rm -rf "$work"
fi

criterion "authselect profile $profile is still selected" profile_kept
criterion "authselect feature with-faillock is enabled" feature_enabled with-faillock
criterion "authselect feature with-pwhistory is enabled" feature_enabled with-pwhistory
criterion "PAM files match the authselect configuration" authselect check

criterion "File $POLICY exists" test -f "$POLICY"
criterion "pwquality minlen is 12 (50-policy.conf)" pwquality_is minlen 12
criterion "pwquality minclass is 3 (50-policy.conf)" pwquality_is minclass 3
criterion "pwquality dictcheck is 1 (50-policy.conf)" pwquality_is dictcheck 1
criterion "pwquality enforce_for_root is set (50-policy.conf)" conf_flag "$POLICY" enforce_for_root

rc=1
[ "$(conf_value "$FAILLOCK" deny)" = 3 ] && rc=0
criterion_result "faillock.conf has deny = 3" "$rc"
rc=1
[ "$(conf_value "$FAILLOCK" unlock_time)" = 600 ] && rc=0
criterion_result "faillock.conf has unlock_time = 600" "$rc"
rc=1
[ "$(conf_value "$PWHISTORY" remember)" = 5 ] && rc=0
criterion_result "pwhistory.conf has remember = 5" "$rc"
criterion "pwhistory.conf has enforce_for_root" conf_flag "$PWHISTORY" enforce_for_root

criterion_result "User $TEST_USER is locked after 3 failed logins" "$lock_rc"
criterion_result "passwd rejects a password of 11 characters" "$short_rc"
criterion_result "passwd rejects a password with 2 character classes" "$classes_rc"
criterion_result "passwd accepts a password that meets the policy" "$good_rc"
criterion_result "passwd rejects the previous password of $TEST_USER" "$history_rc"
grade_end
