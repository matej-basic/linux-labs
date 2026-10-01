#!/bin/bash
# users-03 grader
source /opt/linux-labs/lib/grading.sh

STATE_FILE=/opt/linux-labs/state/users-03
SHARED=/srv/shared
ANALYTICS=/srv/shared/analytics

grade_begin users-03
grade_require_state users-03 "$STATE_FILE"

# gid_is <group> <gid>
gid_is() {
	[ "$(getent group "$1" | cut -d: -f3)" = "$2" ]
}

# uid_is <user> <uid>
uid_is() {
	[ "$(getent passwd "$1" | cut -d: -f3)" = "$2" ]
}

# primary_group_is <user> <group>
primary_group_is() {
	[ "$(id -gn "$1" 2>/dev/null)" = "$2" ]
}

# in_group <user> <group>
in_group() {
	id -nG "$1" 2>/dev/null | tr ' ' '\n' | grep -qx "$2"
}

# shell_is <user> <shell>
shell_is() {
	[ "$(getent passwd "$1" | cut -d: -f7)" = "$2" ]
}

# home_is <user> <group>: /home/<user> is <user>:<group> with mode 750
home_is() {
	local d="/home/$1"
	[ -d "$d" ] || return 1
	[ "$(stat -c %U:%G "$d")" = "$1:$2" ] || return 1
	[ "$(stat -c %a "$d")" = 750 ]
}

# not_in_group <user> <group>
not_in_group() {
	! in_group "$1" "$2"
}

# Account expiry of charlie is 2099-12-31 (shadow field 8, days since epoch)
charlie_expires() {
	local want have
	want=$(( $(date -u -d 2099-12-31 +%s) / 86400 ))
	have=$(getent shadow charlie | cut -d: -f8)
	[ "$have" = "$want" ]
}

# dir_is <dir> <group>: owned root:<group>, base permissions rwxr-x---
dir_is() {
	local acl
	[ -d "$1" ] && [ ! -L "$1" ] || return 1
	[ "$(stat -c %U:%G "$1")" = "root:$2" ] || return 1
	acl=$(getfacl -c -p "$1" 2>/dev/null) || return 1
	grep -qx 'user::rwx' <<<"$acl" &&
		grep -qx 'group::r-x' <<<"$acl" &&
		grep -qx 'other::---' <<<"$acl"
}

# acl_has <dir> <entry>
acl_has() {
	getfacl -c -p "$1" 2>/dev/null | grep -qx "$2"
}

criterion "Group devops exists with GID 2000" gid_is devops 2000
criterion "Group analytics exists with GID 2001" gid_is analytics 2001
criterion "User bob exists with UID 1010" uid_is bob 1010
criterion "User bob has primary group devops" primary_group_is bob devops
criterion "User bob is a member of wheel" in_group bob wheel
criterion "User bob is a member of analytics" in_group bob analytics
criterion "User bob has login shell /bin/bash" shell_is bob /bin/bash
criterion "/home/bob is bob:devops with mode 750" home_is bob devops
criterion "User charlie exists with UID 1011" uid_is charlie 1011
criterion "User charlie has primary group analytics" primary_group_is charlie analytics
criterion "User charlie is a member of wheel" in_group charlie wheel
criterion "User charlie has login shell /bin/bash" shell_is charlie /bin/bash
criterion "/home/charlie is charlie:analytics with mode 750" home_is charlie analytics
criterion "Account charlie expires on 2099-12-31" charlie_expires
criterion "$SHARED is root:devops with base rwxr-x---" dir_is "$SHARED" devops
criterion "$SHARED has default ACL group:devops:rwx" acl_has "$SHARED" default:group:devops:rwx
criterion "$ANALYTICS is root:analytics, base rwxr-x---" dir_is "$ANALYTICS" analytics
criterion "$ANALYTICS has ACL entry user:charlie:rwx" acl_has "$ANALYTICS" user:charlie:rwx
criterion "User charlie is not a member of devops" not_in_group charlie devops
criterion "User charlie can write in $ANALYTICS" runuser -u charlie -- test -w "$ANALYTICS"
grade_end
