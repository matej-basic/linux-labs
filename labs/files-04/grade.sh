#!/bin/bash
# files-04 grader
source /opt/linux-labs/lib/grading.sh

ROOT=/srv/archive
STATE_FILE=/opt/linux-labs/state/files-04
types=(report memo chart)
months=(sep oct nov dec)

grade_begin files-04
grade_require_state files-04 "$STATE_FILE"
owner=$(head -n 1 "$STATE_FILE")

# Expected paths
dirs=()
files=()
for t in "${types[@]}"; do
	dirs+=("$ROOT/$t")
	for m in "${months[@]}"; do
		dirs+=("$ROOT/$t/$m")
		for l in a b c; do
			for d in 1 2 3; do
				files+=("$ROOT/$t/$m/${t}_${m}_${l}${d}")
			done
		done
	done
done

# The 12 type/month directories exist
month_dirs_exist() {
	local t m
	for t in "${types[@]}"; do
		for m in "${months[@]}"; do
			[ -d "$ROOT/$t/$m" ] || return 1
		done
	done
}

# Every expected file is a regular file (not a symlink) in its place
files_in_place() {
	local f
	for f in "${files[@]}"; do
		[ -f "$f" ] && [ ! -L "$f" ] || return 1
	done
}

# No files (anything but directories) directly in $ROOT or a type directory
no_loose_files() {
	local base
	for base in "$ROOT" "$ROOT"/*/; do
		[ -d "$base" ] || continue
		[ -z "$(find "$base" -maxdepth 1 -mindepth 1 ! -type d -print -quit 2>/dev/null)" ] || return 1
	done
}

# Nothing in the tree except the expected directories and files
no_extra_entries() {
	local expected actual
	expected=$(printf '%s\n' "${dirs[@]}" "${files[@]}" | sort)
	actual=$(find "$ROOT" -mindepth 1 2>/dev/null | sort)
	[ -z "$(comm -13 <(echo "$expected") <(echo "$actual"))" ]
}

# Every expected path that exists belongs to the lab owner
owned_by_owner() {
	local p
	for p in "${dirs[@]}" "${files[@]}"; do
		[ -e "$p" ] || continue
		[ "$(stat -c %U "$p" 2>/dev/null)" = "$owner" ] || return 1
	done
}

criterion "Directory $ROOT exists" test -d "$ROOT"
criterion "All 12 <type>/<month> directories exist" month_dirs_exist
criterion "All 108 files are in their <type>/<month> directory" files_in_place
criterion "No loose files in $ROOT or the type directories" no_loose_files
criterion "No extra files or directories in $ROOT" no_extra_entries
criterion "Everything in $ROOT is owned by $owner" owned_by_owner
grade_end
