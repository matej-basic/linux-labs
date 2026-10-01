#!/bin/bash
# files-03 grader
source /opt/linux-labs/lib/grading.sh

ROOT=/srv/secure
ARCHIVE=/tmp/backup.tar.gz

# $1 path, $2 expected owner:group, $3 expected mode
owner_mode() {
	[ "$(stat -c '%U:%G %a' "$1" 2>/dev/null)" = "$2 $3" ]
}

# $1 path, $2 expected ACL entry line
has_acl() {
	getfacl -cp "$1" 2>/dev/null | grep -qx "$2"
}

# $1 member name, $2 mode string, $3 owner (name form), $4 owner (numeric)
archive_entry() {
	tar -tvzf "$ARCHIVE" 2>/dev/null | awk -v n="$1" -v m="$2" -v o1="$3" -v o2="$4" '
		{ p = $NF; sub(/\/$/, "", p)
		  if (p == n && $1 == m && ($2 == o1 || $2 == o2)) found = 1 }
		END { exit !found }'
}

group_gid() {
	[ "$(getent group developers | cut -d: -f3)" = "3000" ]
}

alice_uid() {
	[ "$(getent passwd alice | cut -d: -f3)" = "1001" ]
}

deploy_ok() {
	[ -f "$ROOT/bin/deploy.sh" ] && [ ! -L "$ROOT/bin/deploy.sh" ] &&
		owner_mode "$ROOT/bin/deploy.sh" root:root 4755
}

archive_valid() {
	[ -f "$ARCHIVE" ] && gzip -t "$ARCHIVE" && tar -tzf "$ARCHIVE"
}

archive_has_tree() {
	local list
	list=$(tar -tzf "$ARCHIVE" 2>/dev/null | sed 's#/$##') || return 1
	local p
	for p in srv/secure srv/secure/bin srv/secure/bin/deploy.sh \
		srv/secure/shared srv/secure/tmp; do
		printf '%s\n' "$list" | grep -qx "$p" || return 1
	done
}

archive_modes() {
	archive_entry srv/secure drwxr-xr-x root/root 0/0 &&
		archive_entry srv/secure/bin/deploy.sh -rwsr-xr-x root/root 0/0 &&
		archive_entry srv/secure/shared drwxrws--- root/developers 0/3000 &&
		archive_entry srv/secure/tmp drwxrwxrwt root/root 0/0
}

grade_begin files-03

criterion "Group developers exists with GID 3000" group_gid
criterion "User alice exists with UID 1001" alice_uid
criterion "$ROOT is a directory owned by root:root, mode 755" \
	owner_mode "$ROOT" root:root 755
criterion "$ROOT/bin/deploy.sh is owned by root, mode 4755" deploy_ok
criterion "$ROOT/shared is root:developers, mode 2770" \
	owner_mode "$ROOT/shared" root:developers 2770
criterion "$ROOT/shared gives group developers rwx by ACL" \
	has_acl "$ROOT/shared" group:developers:rwx
criterion "$ROOT/tmp is owned by root, mode 1777" \
	owner_mode "$ROOT/tmp" root:root 1777
criterion "$ROOT/tmp gives user alice rwx by ACL" \
	has_acl "$ROOT/tmp" user:alice:rwx
criterion "$ARCHIVE is a gzip-compressed tar archive" archive_valid
criterion "The archive contains the whole $ROOT tree" archive_has_tree
criterion "The archive records the owners and modes of the tree" \
	archive_modes
grade_end
