#!/bin/bash
# files-06 grader
source /opt/linux-labs/lib/load-config.sh
source /opt/linux-labs/lib/grading.sh
load_lab_config

LAB=files-06
STATE_FILE=/opt/linux-labs/state/$LAB
ARCHIVE=/srv/projects.tar.xz
BACKUP=/srv/backup/projects
RESTORE=/srv/restore/projects

grade_begin files-06
grade_require_state files-06 "$STATE_FILE"

[ "$NODES_ENABLED" = "true" ] || grade_abort "Multi-node labs are enabled in the configuration"
[ "$NODE_COUNT" -ge 2 ] 2>/dev/null || grade_abort "The configuration defines at least 2 nodes"

N1=$(get_node_ip 1)
N2=$(get_node_ip 2)
for ip in "$N1" "$N2"; do
	test_node_connectivity "$ip" >/dev/null 2>&1 || grade_abort "Nodes 1 and 2 are reachable over SSH"
done

# manifest <dir>: one line per entry of the tree, sorted by path:
# <path> <type> <mode> <owner> <group> <mtime> <sha256>, where mtime and
# sha256 are "-" for anything but a regular file (the same function as
# in setup.sh, which wrote the expected tree to the state file)
manifest() (
	cd "$1" 2>/dev/null || exit 1
	find . | LC_ALL=C sort | while read -r p; do
		if [ -L "$p" ]; then t=l
		elif [ -d "$p" ]; then t=d
		elif [ -f "$p" ]; then t=f
		else t=o
		fi
		m=- s=-
		if [ "$t" = f ]; then
			m=$(stat -c %Y "$p")
			s=$(sha256sum < "$p" | cut -c 1-64)
		fi
		printf '%s %s %s %s %s\n' "$p" "$t" "$(stat -c '%a %U %G' "$p")" "$m" "$s"
	done
)

# manifest_on <ip> <dir>: the manifest of a directory on a node, empty
# when the directory does not exist
manifest_on() {
	{
		declare -f manifest
		printf 'manifest %s\n' "$2"
	} | run_on_node "$1" "sudo -n bash -s" 2>/dev/null
}

expected=$(cat "$STATE_FILE")
expected_notmp=$(printf '%s\n' "$expected" | awk '$1 !~ /\.tmp$/')
source_now=$(manifest_on "$N1" /srv/projects)
backup=$(manifest_on "$N2" "$BACKUP")
restore=$(manifest_on "$N1" "$RESTORE")

# same <fields> <expected> <actual>: the selected fields of two
# manifests are equal and the actual one is not empty
same() {
	[ -n "$3" ] || return 1
	[ "$(printf '%s\n' "$2" | cut -d ' ' -f "$1")" = "$(printf '%s\n' "$3" | cut -d ' ' -f "$1")" ]
}

no_tmp_on_node2() {
	[ -n "$backup" ] || return 1
	! printf '%s\n' "$backup" | awk '$1 ~ /\.tmp$/ { found = 1 } END { exit !found }'
}

# The archive: xz magic bytes FD 37 7A 58 5A 00
archive_is_xz() {
	local magic
	magic=$(run_on_node "$N1" "sudo -n head -c 6 $ARCHIVE" 2>/dev/null | od -An -tx1 | tr -d ' \n')
	[ "$magic" = fd377a585a00 ]
}

# Members of the archive as "<name> <owner>/<group>", names without a
# leading ./ and without the trailing / of directories
members=$(run_on_node "$N1" "sudo -n tar -tvf $ARCHIVE" 2>/dev/null |
	awk 'NF >= 6 { n = $6; sub(/^\.\//, "", n); sub(/\/$/, "", n); print n, $2 }' |
	LC_ALL=C sort)
expected_members=$(printf '%s\n' "$expected" |
	awk '{ p = $1; sub(/^\.\/?/, "", p); n = (p == "" ? "projects" : "projects/" p); print n, $4 "/" $5 }' |
	LC_ALL=C sort)

archive_names() {
	[ -n "$members" ] || return 1
	[ "$(printf '%s\n' "$members" | cut -d ' ' -f 1)" = "$(printf '%s\n' "$expected_members" | cut -d ' ' -f 1)" ]
}

# Owners and groups, also when the member names carry the leading srv/
# of an archive made from /
archive_owners() {
	[ -n "$members" ] || return 1
	[ "$(printf '%s\n' "$members" | sed 's|^srv/||' | LC_ALL=C sort)" = "$expected_members" ]
}

criterion "Directory /srv/projects on node 1 is unchanged" same 1-7 "$expected" "$source_now"
criterion "Archive $ARCHIVE on node 1 is xz-compressed" archive_is_xz
criterion "The archive holds the tree under projects/, nothing else" archive_names
criterion "The archive members keep their owners and groups" archive_owners
criterion "$BACKUP on node 2 has the files without .tmp" same 1,2,7 "$expected_notmp" "$backup"
criterion "The node 2 copy keeps modes, owners and groups" same 1,3,4,5 "$expected_notmp" "$backup"
criterion "The node 2 copy keeps the file modification times" same 1,6 "$expected_notmp" "$backup"
criterion "The node 2 copy has no .tmp files" no_tmp_on_node2
criterion "$RESTORE on node 1 has all files of the tree" same 1,2,7 "$expected" "$restore"
criterion "The extracted copy keeps modes, owners, groups and times" same 1,3,4,5,6 "$expected" "$restore"
grade_end
