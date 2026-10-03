#!/bin/bash
# files-09 grader: checks the links in /srv/linklab against the inode
# numbers setup recorded, and the list of names in the answer file.
source /opt/linux-labs/lib/grading.sh

ROOT=/srv/linklab
STATE_FILE=/opt/linux-labs/state/files-09
OLD_TEXT='Legacy data, kept for reference.'
REPORT_TEXT='Quarterly report: 42 tickets closed, 3 open.'

grade_begin files-09
grade_require_state files-09 "$STATE_FILE"

state() { sed -n "s/^$1=//p" "$STATE_FILE"; }
answers=$(state answers)
report_inode=$(state report_inode)
old_inode=$(state old_inode)
shared_inode=$(state shared_inode)
conf_inode=$(state conf_inode)

# inode <path>: the inode number of the path itself (not followed)
inode() { stat -c %i "$1" 2>/dev/null; }

backup_ok() {
	local f="$ROOT/backup/report.txt"
	[ -f "$f" ] && [ ! -L "$f" ] || return 1
	[ "$(inode "$f")" = "$report_inode" ] &&
		[ "$(inode "$ROOT/data/report.txt")" = "$report_inode" ] &&
		[ "$(stat -c %h "$f")" -ge 2 ]
}

current_ok() {
	[ -L "$ROOT/current" ] &&
		[ "$(readlink "$ROOT/current")" = "releases/v2" ]
}

appconf_ok() {
	[ -L "$ROOT/app.conf" ] &&
		[ "$(readlink "$ROOT/app.conf")" = "/srv/linklab/etc/app.conf" ] &&
		[ -f "$ROOT/app.conf" ]
}

# The answer file lists exactly the names of the shared inode; order,
# blank lines, trailing spaces and repeated slashes do not matter
names_ok() {
	local f="$answers/inode-names.txt" expected actual
	[ -f "$f" ] || return 1
	expected=$(printf '%s\n' "$ROOT/archive/2023/blob.dat" \
		"$ROOT/data/shared.dat" "$ROOT/etc/cache/store.dat" | LC_ALL=C sort)
	actual=$(sed -e 's/\r$//' -e 's/[[:space:]]*$//' -e 's|//*|/|g' "$f" |
		grep -v '^$' | LC_ALL=C sort)
	[ "$actual" = "$expected" ]
}

old_gone() {
	[ ! -e "$ROOT/data/old.txt" ] && [ ! -L "$ROOT/data/old.txt" ]
}

# The archive copy keeps the original inode and content, and is its
# only name
old_copy_ok() {
	local f="$ROOT/archive/2024/old-copy.txt"
	[ -f "$f" ] && [ ! -L "$f" ] || return 1
	[ "$(inode "$f")" = "$old_inode" ] &&
		[ "$(stat -c %h "$f")" -eq 1 ] &&
		[ "$(cat "$f")" = "$OLD_TEXT" ]
}

latest_ok() {
	local t
	[ -L "$ROOT/latest" ] || return 1
	t=$(readlink "$ROOT/latest")
	[ "$t" = "releases/v2" ] || [ "$t" = "/srv/linklab/releases/v2" ]
}

no_stray_link() {
	[ ! -e "$ROOT/releases/v1/v2" ] && [ ! -L "$ROOT/releases/v1/v2" ]
}

# The rest of the tree as setup left it
rest_unchanged() {
	local p
	[ "$(cat "$ROOT/data/report.txt" 2>/dev/null)" = "$REPORT_TEXT" ] || return 1
	[ "$(cat "$ROOT/releases/v1/VERSION" 2>/dev/null)" = "release v1" ] || return 1
	[ "$(cat "$ROOT/releases/v2/VERSION" 2>/dev/null)" = "release v2" ] || return 1
	for p in releases/v1 releases/v2; do
		[ -d "$ROOT/$p" ] && [ ! -L "$ROOT/$p" ] || return 1
	done
	[ -f "$ROOT/etc/app.conf" ] && [ ! -L "$ROOT/etc/app.conf" ] || return 1
	[ "$(inode "$ROOT/etc/app.conf")" = "$conf_inode" ] || return 1
	for p in data/shared.dat archive/2023/blob.dat etc/cache/store.dat; do
		[ -f "$ROOT/$p" ] && [ ! -L "$ROOT/$p" ] || return 1
		[ "$(inode "$ROOT/$p")" = "$shared_inode" ] || return 1
	done
	[ "$(stat -c %h "$ROOT/data/shared.dat")" -eq 3 ] || return 1
	[ "$(inode "$ROOT/archive/2024/shared.dat")" != "$shared_inode" ] &&
		[ -f "$ROOT/archive/2024/shared.dat" ] || return 1
	[ "$(readlink "$ROOT/etc/shared.lnk")" = "../data/shared.dat" ]
}

criterion "backup/report.txt is a hard link to data/report.txt" backup_ok
criterion "current is a symbolic link to releases/v2" current_ok
criterion "app.conf is a working link to /srv/linklab/etc/app.conf" appconf_ok
criterion "inode-names.txt lists every name of shared.dat" names_ok
criterion "data/old.txt no longer exists" old_gone
criterion "archive/2024/old-copy.txt keeps the original data" old_copy_ok
criterion "latest is a symbolic link to releases/v2" latest_ok
criterion "releases/v1 holds no link named v2" no_stray_link
criterion "The other files in $ROOT are unchanged" rest_unchanged
grade_end
