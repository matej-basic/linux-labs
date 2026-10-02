#!/bin/bash
# users-02 grader
source /opt/linux-labs/lib/grading.sh

LIMITS=/etc/security/limits.d/70-contractors.conf
STATE_FILE=/opt/linux-labs/state/users-02

grade_begin users-02
grade_require_state users-02 "$STATE_FILE"

# user_home <user>: the account exists with its home directory in place
user_home() {
	local u=$1 home
	home=$(getent passwd "$u" | cut -d: -f6)
	[ "$home" = "/home/$u" ] && [ -d "$home" ] || return 1
	[ "$(stat -c %U "$home")" = "$u" ]
}

primary_group_is() {
	[ "$(id -gn "$1" 2>/dev/null)" = "$2" ]
}

shell_is() {
	[ "$(getent passwd "$1" | cut -d: -f7)" = "$2" ]
}

# max_age_is <user> <days>: maximum password age in /etc/shadow
max_age_is() {
	[ "$(getent shadow "$1" | cut -d: -f5)" = "$2" ]
}

# password_is <user> <password>: hash the password with the settings of
# the /etc/shadow entry through crypt(3). This covers every hash format
# the system writes, including $6$rounds=N$ (EL9 sets
# SHA_CRYPT_MAX_ROUNDS in login.defs), which openssl passwd cannot
# reproduce. platform-python is on every EL8 system, python3 on EL9.
password_is() {
	local hash py
	hash=$(getent shadow "$1" | cut -d: -f2)
	case $hash in
	"\$"*) ;;
	*) return 1 ;;
	esac
	for py in /usr/libexec/platform-python /usr/bin/python3; do
		[ -x "$py" ] && break
	done
	[ -x "$py" ] || return 1
	HASH=$hash PW=$2 "$py" -c '
import crypt, os, sys
h = os.environ["HASH"]
sys.exit(0 if crypt.crypt(os.environ["PW"], h) == h else 1)'
}

chage_field_is() {
	local user=$1 field=$2 want=$3
	[ "$(LC_ALL=C chage -l "$user" 2>/dev/null | sed -n "s/^${field}[[:space:]]*:[[:space:]]*//p")" = "$want" ]
}

# limit_set <item> <value>: soft and hard limit for @contractors
limit_set() {
	[ -f "$LIMITS" ] || return 1
	awk -v item="$1" -v val="$2" '
		/^[[:space:]]*#/ { next }
		$1 == "@contractors" && $3 == item && $4 == val {
			if ($2 == "-" || $2 == "soft") s = 1
			if ($2 == "-" || $2 == "hard") h = 1
		}
		END { exit !(s && h) }' "$LIMITS"
}

# login_defs_is <key> <value>: the last active setting of the key
login_defs_is() {
	[ "$(awk -v k="$1" '$1 == k { v = $2 } END { print v }' /etc/login.defs)" = "$2" ]
}

criterion "Group contractors exists" getent group contractors

criterion "User dave has home /home/dave owned by dave" user_home dave
criterion "User dave has primary group contractors" primary_group_is dave contractors
criterion "User dave has login shell /bin/bash" shell_is dave /bin/bash
criterion "User dave has maximum password age 30 days" max_age_is dave 30
criterion "User dave has the password contractor123" password_is dave contractor123

criterion "User eve has home /home/eve owned by eve" user_home eve
criterion "User eve has primary group contractors" primary_group_is eve contractors
criterion "User eve has login shell /bin/bash" shell_is eve /bin/bash
criterion "Account eve expires on 2030-12-31" chage_field_is eve "Account expires" "Dec 31, 2030"
criterion "Password of eve never expires" chage_field_is eve "Password expires" never
criterion "User eve has the password eve-pass" password_is eve eve-pass

criterion "File $LIMITS exists" test -f "$LIMITS"
criterion "Group contractors has 1024 open files (soft and hard)" limit_set nofile 1024
criterion "Group contractors has 512 processes (soft and hard)" limit_set nproc 512

criterion "PASS_MAX_DAYS is 90 in /etc/login.defs" login_defs_is PASS_MAX_DAYS 90
criterion "PASS_MIN_DAYS is 1 in /etc/login.defs" login_defs_is PASS_MIN_DAYS 1
criterion "PASS_WARN_AGE is 14 in /etc/login.defs" login_defs_is PASS_WARN_AGE 14
grade_end
